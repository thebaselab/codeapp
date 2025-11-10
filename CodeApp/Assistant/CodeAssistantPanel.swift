//
//  CodeAssistantPanel.swift
//  CodeApp
//
//  Created by Codex.
//

import MarkdownUI
import SwiftUI
import UIKit
#if os(macOS)
    import AppKit
#endif

struct CodeAssistantPanel: View {

    @ObservedObject var viewModel: CodeAssistantViewModel
    @EnvironmentObject var app: MainApp

    @State private var showsAttachmentPicker = false
    @State private var modelDraft: String = ""

    private let scrollViewID = "code-assistant-scroll"

    var body: some View {
        VStack(spacing: 12) {
            header
            if !viewModel.history.isEmpty {
                historySection
            }
            providerControls
            Divider()
            messagesView
            attachmentsView
            actionRow
            inputRow
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 24, x: 0, y: 16)
        .onAppear {
            modelDraft = viewModel.currentModel
        }
        .onChange(of: viewModel.selectedProvider) { _ in
            modelDraft = viewModel.currentModel
        }
        .onChange(of: viewModel.currentModel) { newValue in
            guard newValue != modelDraft else { return }
            modelDraft = newValue
        }
        .sheet(isPresented: $showsAttachmentPicker) {
            AttachmentPickerView(root: app.workSpaceStorage.currentDirectory) { item in
                viewModel.attach(item: item)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Code Assistant", systemImage: "bolt.horizontal.circle")
                    .font(.headline)
                Spacer()
                if viewModel.isStreaming {
                    ProgressView()
                }
            }
            HStack {
                Text(viewModel.activeConversationTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                historyMenu
            }
        }
    }

    private var historyMenu: some View {
        Menu {
            Button {
                viewModel.startNewConversation()
            } label: {
                Label("New Chat", systemImage: "plus")
            }

            if viewModel.history.isEmpty {
                Text("No previous chats")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.history) { conversation in
                    Button {
                        viewModel.loadConversation(conversation)
                    } label: {
                        Label(conversation.title, systemImage: "message")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    viewModel.clearHistory()
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
            }
        } label: {
            Label("History", systemImage: "clock.arrow.circlepath")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Chats")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.history) { conversation in
                        HistoryChip(
                            conversation: conversation,
                            onSelect: { viewModel.loadConversation(conversation) },
                            onDelete: { viewModel.deleteConversation(conversation) }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var providerControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Provider", selection: $viewModel.selectedProvider) {
                ForEach(CodeAssistantProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.menu)

            HStack {
                TextField("Model", text: $modelDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.subheadline, design: .monospaced))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .onSubmit {
                        viewModel.updateModel(modelDraft)
                    }

                Menu {
                    ForEach(viewModel.selectedProvider.suggestedModels, id: \.self) { model in
                        Button(model) {
                            modelDraft = model
                            viewModel.updateModel(model)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .padding(8)
                }

                Button {
                    viewModel.updateModel(modelDraft)
                } label: {
                    Text("Apply")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(scrollViewID)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemBackground).opacity(0.001))  // keep scroll gestures
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation {
                    proxy.scrollTo(scrollViewID, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.messages.last?.body ?? "") { _ in
                if viewModel.isStreaming {
                    withAnimation {
                        proxy.scrollTo(scrollViewID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var attachmentsView: some View {
        Group {
            if viewModel.attachments.isEmpty {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(viewModel.attachments) { attachment in
                            AttachmentChipView(
                                attachment: attachment,
                                onRemove: { viewModel.removeAttachment(attachment) })
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var actionRow: some View {
        HStack {
            Button {
                if let active = app.activeTextEditor as? EditorInstanceWithURL {
                    let item = WorkSpaceStorage.FileItemRepresentable(
                        name: active.url.lastPathComponent,
                        url: active.url.absoluteString,
                        isDirectory: false)
                    viewModel.attach(item: item)
                } else {
                    viewModel.errorMessage = "Open a file to attach it quickly."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        viewModel.errorMessage = nil
                    }
                }
            } label: {
                Label("Attach Active File", systemImage: "doc.text.fill")
            }
            .disabled(app.activeTextEditor == nil)

            Button {
                showsAttachmentPicker = true
            } label: {
                Label("Browse Files", systemImage: "paperclip")
            }

            Spacer()

            Button(role: .destructive) {
                viewModel.clearConversation()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(viewModel.messages.isEmpty)
        }
        .font(.footnote)
    }

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Ask the assistant…", text: $viewModel.currentInput, axis: .vertical)
                .lineLimit(1...5)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(.separator))
                )
                .onSubmit {
                    viewModel.updateModel(modelDraft)
                    viewModel.sendMessage()
                }

            Button {
                if viewModel.isStreaming {
                    viewModel.stopStreaming()
                } else {
                    viewModel.updateModel(modelDraft)
                    viewModel.sendMessage()
                }
            } label: {
                Image(
                    systemName: viewModel.isStreaming
                        ? "stop.circle.fill" : "paperplane.circle.fill"
                )
                .font(.system(size: 32))
                .foregroundStyle(viewModel.canSend ? Color.accentColor : Color.gray.opacity(0.5))
            }
            .disabled(!viewModel.canSend && !viewModel.isStreaming)
        }
    }
}

private struct MessageBubbleView: View {
    let message: CodeAssistantViewModel.Message

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                header
                if message.isStreaming && message.body.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Markdown(message.body.isEmpty ? "…" : message.body)
                        .markdownTheme(.gitHub)
                        .markdownBlockStyle(\.codeBlock) { configuration in
                            CopyableCodeBlock(configuration: configuration)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !message.attachments.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(message.attachments) { attachment in
                            Text("📎 \(attachment.name) (\(attachment.formattedSize))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                if let error = message.errorDescription {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(message.role == .user
                        ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
            )
            .frame(maxWidth: 420, alignment: .leading)
            if message.role == .assistant {
                Spacer()
            }
        }
    }

    private var header: some View {
        HStack {
            Label(
                message.role == .user ? "You" : "Assistant",
                systemImage: message.role == .user ? "person.circle" : "sparkles")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(message.createdAt, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
            if message.role == .assistant && !message.body.isEmpty {
                Button {
                    copyMessage()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func copyMessage() {
        #if os(iOS)
            UIPasteboard.general.string = message.body
        #elseif os(macOS)
            NSPasteboard.general?.clearContents()
            NSPasteboard.general?.setString(message.body, forType: .string)
        #endif
    }
}

private struct AttachmentChipView: View {
    let attachment: CodeAssistantViewModel.Attachment
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "paperclip")
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.name).font(.caption)
                Text(attachment.formattedSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(
            Capsule()
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

private struct HistoryChip: View {
    let conversation: CodeAssistantViewModel.Conversation
    var onSelect: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(conversation.title)
                        .font(.caption)
                        .lineLimit(1)
                    Text(conversation.createdAt, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct CopyableCodeBlock: View {
    let configuration: CodeBlockConfiguration
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(configuration.language ?? "code")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    copyToClipboard(configuration.content)
                } label: {
                    Label(
                        didCopy ? "Copied" : "Copy",
                        systemImage: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))

            Divider()

            ScrollView(.horizontal) {
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.9))
                    }
                    .padding()
            }
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
            UIPasteboard.general.string = text
        #elseif os(macOS)
            NSPasteboard.general?.clearContents()
            NSPasteboard.general?.setString(text, forType: .string)
        #endif
        withAnimation(.easeInOut(duration: 0.2)) {
            didCopy = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                didCopy = false
            }
        }
    }
}

private struct AttachmentPickerView: View {
    let root: WorkSpaceStorage.FileItemRepresentable
    var onSelect: (WorkSpaceStorage.FileItemRepresentable) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                AttachmentPickerNode(item: root, onSelect: handleSelect)
            }
            .navigationTitle("Select File")
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            })
        }
        .presentationDetents([.medium, .large])
    }

    private func handleSelect(_ item: WorkSpaceStorage.FileItemRepresentable) {
        onSelect(item)
        dismiss()
    }
}

private struct AttachmentPickerNode: View {
    let item: WorkSpaceStorage.FileItemRepresentable
    var onSelect: (WorkSpaceStorage.FileItemRepresentable) -> Void

    var body: some View {
        if let children = item.subFolderItems {
            DisclosureGroup {
                if children.isEmpty {
                    Text("Empty Folder")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(children, id: \.id) { element in
                        AttachmentPickerNode(item: element, onSelect: onSelect)
                    }
                }
            } label: {
                Label(item.name, systemImage: "folder")
            }
        } else {
            Button {
                onSelect(item)
            } label: {
                Label(item.name, systemImage: "doc.text")
                    .lineLimit(1)
            }
        }
    }
}
