//
//  SourceControlView.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import StoreKit
import SwiftGit2
import SwiftUI

struct SourceControlSection: View {
    @EnvironmentObject var App: MainApp

    let onCommit: () async throws -> Void
    let onPush: (Remote) async throws -> Void
    let onFetch: () async throws -> Void
    let onStageAllChanges: () throws -> Void
    let onUnstage: (String) throws -> Void
    let onRevert: (String, Bool) async throws -> Void
    let onStage: ([String]) throws -> Void
    let onShowChangesInDiffEditor: (String) throws -> Void

    var body: some View {
        Group {
            MainSection(
                onCommit: onCommit, onPush: onPush, onFetch: onFetch,
                onStageAllChanges: onStageAllChanges)
            if !App.indexedResources.isEmpty {
                StagedChangesSection(
                    onUnstage: onUnstage,
                    onRevert: onRevert,
                    onStage: onStage,
                    onShowChangesInDiffEditor: onShowChangesInDiffEditor
                )
            }
            WorkingChangesSection(
                onUnstage: onUnstage,
                onRevert: onRevert,
                onStage: onStage,
                onShowChangesInDiffEditor: onShowChangesInDiffEditor
            )
        }
    }

}

private struct MainSection: View {
    @EnvironmentObject var App: MainApp
    @AppStorage("userHasPromptedWithReviewRequest") var userHasPromptedWithReviewRequest = false

    @State var showsIdentitySheet: Bool = false
    @State var remotes: [Remote] = []

    let onCommit: () async throws -> Void
    let onPush: (Remote) async throws -> Void
    let onFetch: () async throws -> Void
    let onStageAllChanges: () throws -> Void

    func onPushButtonTapped(remote: Remote) {
        Task {
            try await onPush(remote)
            await MainActor.run {
                if !userHasPromptedWithReviewRequest,
                    let scene = UIApplication.shared.connectedScenes
                        .first(where: {
                            $0.activationState == .foregroundActive
                        }) as? UIWindowScene
                {
                    SKStoreReviewController.requestReview(in: scene)
                    userHasPromptedWithReviewRequest = true
                }
            }
        }
    }

    var body: some View {
        Section(
            header:
                Text("source_control.title")
                .foregroundColor(Color(id: "sideBarSectionHeader.foreground"))
        ) {
            ZStack(alignment: .leading) {
                TextEditorWithPlaceholder(
                    placeholder: "Message (⌘Enter to commit)", text: $App.commitMessage
                )
                .autocapitalization(.none)
                .disableAutocorrection(true)
            }
            .frame(minHeight: 25)
            .padding(.horizontal, 4)
            .background(Color.init(id: "input.background"))
            .cornerRadius(15)

            HStack {
                if App.indexedResources.isEmpty {
                    Text("errors.source_control.no_staged_changes").foregroundColor(.gray).font(
                        .system(size: 12, weight: .light))
                } else {
                    Text(
                        "Commit \(App.indexedResources.count) file\(App.indexedResources.count > 1 ? "s" : "") on '\(App.branch)'..."
                    ).foregroundColor(.gray).font(.system(size: 12, weight: .light))
                }

                Spacer()
                Button(action: {
                    Task {
                        do {
                            try await onCommit()
                        } catch SourceControlError.authorIdentityMissing {
                            await MainActor.run {
                                showsIdentitySheet.toggle()
                            }
                        } catch {
                            App.notificationManager.showErrorMessage(error.localizedDescription)
                        }
                    }
                }) {
                    Image(systemName: "checkmark.circle")
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .hoverEffect(.highlight)
                .font(.system(size: 16))
                .foregroundColor(Color.init(id: "activityBar.foreground"))

                Menu {
                    Section {
                        Menu {
                            ForEach(remotes, id: \.hashValue) { remote in
                                Button("\(remote.name) - \(remote.URL)") {
                                    onPushButtonTapped(remote: remote)
                                }
                            }
                        } label: {
                            Label("Push", systemImage: "square.and.arrow.up")
                        }

                        Button(action: {
                            Task {
                                try await onFetch()
                            }
                        }) {
                            Label("Fetch", systemImage: "square.and.arrow.down")
                        }
                    }

                    Section {
                        Button(action: {
                            try? onStageAllChanges()
                        }) {
                            Label("Stage All Changes", systemImage: "plus.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .hoverEffect(.highlight)
                        .font(.system(size: 16))
                        .foregroundColor(Color.init(id: "activityBar.foreground"))
                }
                .onAppear {
                    Task {
                        self.remotes =
                            (try? await App.workSpaceStorage.gitServiceProvider?
                                .remotes()) ?? []
                    }
                }

            }.sheet(isPresented: $showsIdentitySheet) {
                NavigationView {
                    SourceControlIdentityConfiguration()
                }
            }
        }
    }
}

private struct WorkingChangesSection: View {
    @EnvironmentObject var App: MainApp

    let onUnstage: (String) throws -> Void
    let onRevert: (String, Bool) async throws -> Void
    let onStage: ([String]) throws -> Void
    let onShowChangesInDiffEditor: (String) throws -> Void

    var body: some View {
        Section(
            header:
                Text("Changes")
                .foregroundColor(Color(id: "sideBarSectionHeader.foreground"))
        ) {
            if App.workingResources.isEmpty {
                DescriptionText("No changes are made in the working directory.")
            }
            ForEach(
                Array(App.workingResources.keys.sorted { $0.absoluteString < $1.absoluteString }),
                id: \.self
            ) { value in
                SourceControlEntry(
                    itemUrl: value,
                    isIndex: false,
                    onUnstage: onUnstage,
                    onRevert: onRevert,
                    onStage: onStage,
                    onShowChangesInDiffEditor: onShowChangesInDiffEditor
                )
                .frame(height: 16)
            }
        }
    }
}

private struct StagedChangesSection: View {

    @EnvironmentObject var App: MainApp

    let onUnstage: (String) throws -> Void
    let onRevert: (String, Bool) async throws -> Void
    let onStage: ([String]) throws -> Void
    let onShowChangesInDiffEditor: (String) throws -> Void

    var body: some View {
        Section(
            header:
                Text("Staged Changes")
                .foregroundColor(Color(id: "sideBarSectionHeader.foreground"))
        ) {
            ForEach(
                Array(App.indexedResources.keys.sorted { $0.absoluteString < $1.absoluteString }),
                id: \.self
            ) { value in
                SourceControlEntry(
                    itemUrl: value,
                    isIndex: true,
                    onUnstage: onUnstage,
                    onRevert: onRevert,
                    onStage: onStage,
                    onShowChangesInDiffEditor: onShowChangesInDiffEditor
                )
                .frame(height: 16)
            }
        }
    }
}
