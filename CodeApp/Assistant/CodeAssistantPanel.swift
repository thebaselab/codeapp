//
//  CodeAssistantPanel.swift
//  CodeApp
//
//  Created by Arya Mirsepasi.
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var showsAttachmentPicker = false
    @State private var showsHistorySheet = false
    @State private var showsModelPicker = false

    private let scrollViewID = "code-assistant-scroll"

    var body: some View {
        VStack(spacing: 0) {
            // Simplified header with essential actions
            header
            
            Divider()
            
            // Main conversation view
            messagesView
            
            Divider()
            
            // Attachments (when present)
            attachmentsView
            
            // Input area
            inputSection
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 24, x: 0, y: 16)
        .sheet(isPresented: $showsAttachmentPicker) {
            AttachmentPickerView(root: app.workSpaceStorage.currentDirectory) { item in
                viewModel.attach(item: item)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showsHistorySheet) {
            ChatHistoryView(viewModel: viewModel)
        }
        .sheet(isPresented: $showsModelPicker) {
            ModelSelectionView(viewModel: viewModel)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            // Title with streaming indicator
            VStack(alignment: .leading, spacing: 2) {
                Text("Code Assistant")
                    .font(.headline)
                
                HStack(spacing: 6) {
                    if viewModel.isStreaming {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.activeConversationTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Essential header actions
            Button {
                viewModel.startNewConversation()
            } label: {
                Label("New Chat", systemImage: "square.and.pencil")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            
            Button {
                showsHistorySheet = true
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)

            Button {
                showsModelPicker = true
            } label: {
                Label("Model", systemImage: "brain")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.messages.isEmpty {
                    emptyStateView
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                        }
                        Color.clear
                            .frame(height: 1)
                            .id(scrollViewID)
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground).opacity(0.001))
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(scrollViewID, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.messages.last?.body ?? "") { _ in
                if viewModel.isStreaming {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(scrollViewID, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Ready to Assist")
                .font(.title2.weight(.semibold))
            
            Text("Ask questions about your code, request refactoring, or get help with debugging.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var attachmentsView: some View {
        Group {
            if !viewModel.attachments.isEmpty {
                VStack(spacing: 0) {
                    Divider()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.attachments) { attachment in
                                AttachmentChipView(
                                    attachment: attachment,
                                    onRemove: { viewModel.removeAttachment(attachment) })
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    private var inputSection: some View {
        VStack(spacing: 8) {
            // Error message (when present)
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Input controls
            HStack(spacing: 8) {
                // Attachment button
                Menu {
                    Button {
                        if let active = app.activeTextEditor {
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
                        Label("Browse Files", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "paperclip")
                        .font(.body)
                }
                .buttonStyle(.borderless)
                
                // Text input
                TextField("Ask the assistant…", text: $viewModel.currentInput, axis: .vertical)
                    .lineLimit(1...5)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
                    .onSubmit {
                        viewModel.sendMessage()
                    }
                
                // Send/Stop button
                Button {
                    if viewModel.isStreaming {
                        viewModel.stopStreaming()
                    } else {
                        viewModel.sendMessage()
                    }
                } label: {
                    Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "paperplane.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(viewModel.canSend || viewModel.isStreaming ? Color.accentColor : Color.gray.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSend && !viewModel.isStreaming)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Model Selection View

private struct ModelSelectionView: View {
    @ObservedObject var viewModel: CodeAssistantViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var modelDraft: String = ""
    @State private var showCustomModelField = false
    @FocusState private var customModelFieldIsFocused: Bool

    private var trimmedDraft: String {
        modelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        NavigationStack {
            List {
                providerSection
                suggestedModelsSection
                selectionSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Model")
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        applyModel()
                        dismiss()
                    }
                }
            })
            .onAppear {
                syncDraftWithSelection()
            }
            .onChange(of: viewModel.selectedProvider) { _ in
                syncDraftWithSelection()
            }
        }
    }
    
    private var providerSection: some View {
        Section(header: Text("AI Provider"), footer: Text("Provider keys are managed in Settings.")) {
            Picker("Provider", selection: $viewModel.selectedProvider) {
                ForEach(CodeAssistantProvider.allCases) { provider in
                    HStack(spacing: 8) {
                        Text(provider.displayName)
                    }
                    .tag(provider)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var suggestedModelsSection: some View {
        Section(
            header: Text("Model Presets"),
            footer: Text(
                "Need something else? Choose Custom to enter any model supported by \(viewModel.selectedProvider.displayName)."
            )
        ) {
            ForEach(viewModel.selectedProvider.suggestedModels, id: \.self) { model in
                Button {
                    selectSuggestedModel(model)
                } label: {
                    HStack {
                        Text(model)
                            .font(.body.monospaced())
                        Spacer()
                        if !showCustomModelField && modelDraft == model {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

            Button {
                enableCustomModelEntry()
            } label: {
                HStack {
                    Text("Custom Model…")
                    Spacer()
                    if showCustomModelField {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private var selectionSection: some View {
        Section(
            header: Text(showCustomModelField ? "Custom Model" : "Selected Model"),
            footer: Text("Currently using: \(viewModel.currentModel)")
        ) {
            if showCustomModelField {
                TextField("Model Name", text: $modelDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                    .focused($customModelFieldIsFocused)
            } else {
                Text(modelDraft)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }

            Button {
                applyModel()
                dismiss()
            } label: {
                Label("Use This Model", systemImage: "checkmark.circle.fill")
            }
            .disabled(trimmedDraft.isEmpty)

            Button {
                resetToDefault()
            } label: {
                Label("Reset to Default", systemImage: "arrow.counterclockwise")
            }
        }
    }

    private func applyModel() {
        viewModel.updateModel(trimmedDraft)
        syncDraftWithSelection()
    }

    private func selectSuggestedModel(_ model: String) {
        modelDraft = model
        showCustomModelField = false
    }

    private func enableCustomModelEntry() {
        showCustomModelField = true
        if viewModel.selectedProvider.suggestedModels.contains(modelDraft) {
            modelDraft = ""
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            customModelFieldIsFocused = true
        }
    }

    private func resetToDefault() {
        modelDraft = viewModel.selectedProvider.defaultModel
        showCustomModelField = false
    }

    private func syncDraftWithSelection() {
        let current = viewModel.currentModel
        modelDraft = current
        showCustomModelField = !viewModel.selectedProvider.suggestedModels.contains(current)
    }
}

// MARK: - Message Bubble View

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
    var fillsWidth: Bool = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 12) {
                        Label {
                            Text(conversation.createdAt, style: .date)
                        } icon: {
                            Image(systemName: "clock")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                        Label("\(conversation.messages.count)", systemImage: "bubble.left.and.bubble.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
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
    @EnvironmentObject private var app: MainApp
    @State private var didCopy = false
    @State private var didInsert = false
    private var plainText: String {
        configuration.content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(configuration.language?.uppercased() ?? "CODE")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    insertIntoActiveFile()
                } label: {
                    Label(
                        didInsert ? "Inserted" : "Insert",
                        systemImage: didInsert ? "checkmark.circle.fill" : "arrow.down.doc")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                Button {
                    copyToClipboard(plainText)
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

    private func insertIntoActiveFile() {
        guard app.activeTextEditor != nil else {
            app.notificationManager.showWarningMessage(
                "Open a file in the editor to insert code.")
            return
        }
        Task {
            await app.monacoInstance.insertTextAtCurrentCursor(text: plainText)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    didInsert = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    didInsert = false
                }
            }
        }
    }
}

private struct AttachmentPickerView: View {
    let root: WorkSpaceStorage.FileItemRepresentable
    var onSelect: (WorkSpaceStorage.FileItemRepresentable) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
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

private struct ChatHistoryView: View {
    @ObservedObject var viewModel: CodeAssistantViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    private var filteredHistory: [CodeAssistantViewModel.Conversation] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return viewModel.history
        }
        return viewModel.history.filter { conversation in
            conversation.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Recent chats section (top 5)
                if !viewModel.history.isEmpty && searchText.isEmpty {
                    Section(header: Text("Recent")) {
                        ForEach(viewModel.history.prefix(5)) { conversation in
                            chatRow(for: conversation)
                        }
                    }
                }
                
                // All chats section
                if filteredHistory.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: searchText.isEmpty ? "clock.arrow.circlepath" : "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(searchText.isEmpty ? "No Chat History" : "No Results")
                            .font(.headline)
                        Text(searchText.isEmpty ? "Start a new conversation to get started." : "Try adjusting your search.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                } else if searchText.isEmpty && viewModel.history.count > 5 {
                    Section(header: Text("All Chats")) {
                        ForEach(viewModel.history.dropFirst(5)) { conversation in
                            chatRow(for: conversation)
                        }
                    }
                } else if !searchText.isEmpty {
                    Section(header: Text("Search Results")) {
                        ForEach(filteredHistory) { conversation in
                            chatRow(for: conversation)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Chat History")
            .searchable(text: $searchText, prompt: "Search chats")
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                SwiftUI.ToolbarItem(placement: .confirmationAction) {
                    Button {
                        viewModel.startNewConversation()
                        dismiss()
                    } label: {
                        Label("New Chat", systemImage: "square.and.pencil")
                    }
                }
                SwiftUI.ToolbarItem(placement: .automatic) {
                    Menu {
                        Button(role: .destructive) {
                            viewModel.clearHistory()
                        } label: {
                            Label("Clear All History", systemImage: "trash")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                    .disabled(viewModel.history.isEmpty)
                }
            })
        }
    }
    
    private func chatRow(for conversation: CodeAssistantViewModel.Conversation) -> some View {
        Button {
            viewModel.loadConversation(conversation)
            dismiss()
        } label: {
            ChatHistoryRow(conversation: conversation)
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.deleteConversation(conversation)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        #endif
        .contextMenu {
            Button {
                viewModel.loadConversation(conversation)
                dismiss()
            } label: {
                Label("Open Chat", systemImage: "bubble.left.and.bubble.right")
            }
            
            Divider()
            
            Button(role: .destructive) {
                viewModel.deleteConversation(conversation)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct ChatHistoryRow: View {
    let conversation: CodeAssistantViewModel.Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(conversation.title)
                .font(.body.weight(.medium))
                .lineLimit(1)
            HStack(spacing: 12) {
                Label(
                    conversation.createdAt.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "clock"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Label("\(conversation.messages.count)", systemImage: "bubble.left.and.bubble.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

#if DEBUG
    struct CodeAssistantPanel_Previews: PreviewProvider {

        static var previews: some View {
            CodeAssistantPanel(viewModel: previewViewModel)
                .environmentObject(previewApp)
                .frame(width: 540, height: 760)
                .padding()
                .background(Color(.systemGroupedBackground))
        }

        private static let previewApp: MainApp = MainApp()

        private static let sampleAttachment = CodeAssistantViewModel.Attachment(
            url: URL(fileURLWithPath: "/tmp/Preview.swift"),
            name: "Preview.swift",
            byteCount: 132,
            content: """
            struct PreviewWidget: View {
                var body: some View {
                    Text("Hello, Preview")
                }
            }
            """,
            languageHint: "swift",
            wasTruncated: false
        )

        private static let previewMessages: [CodeAssistantViewModel.Message] = [
            CodeAssistantViewModel.Message(
                role: .user,
                body: "Refactor the assistant layout to feel great on iPad.",
                payload: "Refactor the assistant layout to feel great on iPad.",
                createdAt: Date().addingTimeInterval(-600),
                attachments: [sampleAttachment]
            ),
            CodeAssistantViewModel.Message(
                role: .assistant,
                body: """
                Here is a SwiftUI snippet:
                ```swift
                VStack(spacing: 12) {
                    providerPicker
                    modelSelector
                }
                ```
                Keep paddings generous for compact size classes.
                """,
                payload: """
                Here is a SwiftUI snippet:
                ```swift
                VStack(spacing: 12) {
                    providerPicker
                    modelSelector
                }
                ```
                Keep paddings generous for compact size classes.
                """,
                createdAt: Date().addingTimeInterval(-550)
            )
        ]

        private static let previewHistory: [CodeAssistantViewModel.Conversation] = [
            CodeAssistantViewModel.Conversation(
                id: UUID(),
                title: "Improve Markdown Copy",
                messages: previewMessages,
                createdAt: Date().addingTimeInterval(-3_600)
            ),
            CodeAssistantViewModel.Conversation(
                id: UUID(),
                title: "API key storage",
                messages: [],
                createdAt: Date().addingTimeInterval(-8_000)
            )
        ]

        private static var previewViewModel: CodeAssistantViewModel = {
            let suiteName = "codeassistant.panel.preview"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            let viewModel = CodeAssistantViewModel(defaults: defaults)
            viewModel.activeConversationTitle = "Preview Chat"
            viewModel.history = previewHistory
            viewModel.messages = previewMessages
            viewModel.currentInput = "Add timeline style history chips."
            return viewModel
        }()
    }
#endif
