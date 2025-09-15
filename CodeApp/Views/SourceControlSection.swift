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
    let onFetch: (Remote) async throws -> Void
    let onStageAllChanges: () throws -> Void
    let onUnstage: (String) throws -> Void
    let onRevert: (String, Bool) async throws -> Void
    let onStage: ([String]) throws -> Void
    let onShowChangesInDiffEditor: (String) throws -> Void
    let onPull: (Branch, Remote) async throws -> Void
    let onCreateBranch: () -> Void
    let onDeleteBranch: (Branch) -> Void
    let onCreateTag: () -> Void
    let onDeleteTag: (TagReference) -> Void
    let onPushTag: (TagReference, Remote) async throws -> Void

    var body: some View {
        Group {
            MainSection(
                onCommit: onCommit,
                onPush: onPush,
                onFetch: onFetch,
                onStageAllChanges: onStageAllChanges,
                onPull: onPull,
                onCreateBranch: onCreateBranch,
                onDeleteBranch: onDeleteBranch,
                onCreateTag: onCreateTag,
                onDeleteTag: onDeleteTag,
                onPushTag: onPushTag
            )
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
    @State var remoteBranches: [Branch] = []
    @State var localBranches: [Branch] = []
    @State var tags: [TagReference] = []

    let onCommit: () async throws -> Void
    let onPush: (Remote) async throws -> Void
    let onFetch: (Remote) async throws -> Void
    let onStageAllChanges: () throws -> Void
    let onPull: (Branch, Remote) async throws -> Void
    let onCreateBranch: () -> Void
    let onDeleteBranch: (Branch) -> Void
    let onCreateTag: () -> Void
    let onDeleteTag: (TagReference) -> Void
    let onPushTag: (TagReference, Remote) async throws -> Void

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

    func onCommitButtonTapped() {
        Task {
            do {
                try await onCommit()
            } catch SourceControlError.authorIdentityMissing {
                await MainActor.run {
                    showsIdentitySheet.toggle()
                }
            } catch {
                App.notificationManager.showErrorMessage(
                    error.localizedDescription)
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
                    placeholder: "source_control.message_command_enter_to_commit",
                    text: $App.commitMessage
                )
                .autocapitalization(.none)
                .disableAutocorrection(true)
            }
            .frame(minHeight: 60)
            .padding(.horizontal, 4)
            .background(Color.init(id: "input.background"))
            .cornerRadius(10)

            HStack(spacing: 10) {
                if App.indexedResources.isEmpty {
                    Text("errors.source_control.no_staged_changes").foregroundColor(.gray).font(
                        .system(size: 12, weight: .light))
                } else {
                    ZStack {
                        Button("Commit") {
                            onCommitButtonTapped()
                        }
                        .keyboardShortcut(.return, modifiers: [.command])
                        .foregroundColor(.clear).font(.system(size: 1))

                        Text("source_control.commit")
                            .foregroundColor(.white)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(4)
                            .background(
                                Color.init(id: "button.background")
                            )
                            .cornerRadius(10.0)
                            .onTapGesture {
                                onCommitButtonTapped()
                            }
                    }
                }

                Spacer()

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

                        Menu {
                            ForEach(remotes, id: \.hashValue) { remote in
                                Menu {
                                    ForEach(remoteBranches, id: \.hashValue) { branch in
                                        Button("\(branch.name)") {
                                            Task {
                                                try await onPull(branch, remote)
                                            }
                                        }
                                    }
                                } label: {
                                    Text("\(remote.name) - \(remote.URL)")
                                }
                            }
                        } label: {
                            Label("source_control.pull", systemImage: "square.and.arrow.down")
                        }

                        Menu {
                            ForEach(remotes, id: \.hashValue) { remote in
                                Button("\(remote.name) - \(remote.URL)") {
                                    Task {
                                        try await onFetch(remote)
                                    }
                                }
                            }
                        } label: {
                            Label("Fetch", systemImage: "square.and.arrow.down")
                        }
                    }

                    Section {
                        Menu {
                            Button(action: onCreateBranch) {
                                Label("common.create", systemImage: "plus")
                            }

                            Menu {
                                ForEach(localBranches, id: \.hashValue) { branch in
                                    Button("\(branch.name)") {
                                        onDeleteBranch(branch)
                                    }
                                }
                            } label: {
                                Label("common.delete", systemImage: "minus")
                            }
                        } label: {
                            Label("source_control.branch", systemImage: "arrow.triangle.branch")
                        }

                        Menu {
                            Button(action: onCreateTag) {
                                Label("common.create", systemImage: "plus")
                            }
                            Menu {
                                ForEach(tags, id: \.hashValue) { tag in
                                    Button("\(tag.name)") {
                                        onDeleteTag(tag)
                                    }
                                }
                            } label: {
                                Label("common.delete", systemImage: "minus")
                            }

                            Menu {
                                ForEach(tags, id: \.hashValue) { tag in
                                    Menu {
                                        ForEach(remotes, id: \.hashValue) { remote in
                                            Button("\(remote.name) - \(remote.URL)") {
                                                Task {
                                                    try await onPushTag(tag, remote)
                                                }
                                            }
                                        }
                                    } label: {
                                        Text(tag.name)
                                    }
                                }
                            } label: {
                                Label("source_control.push", systemImage: "square.and.arrow.up")
                            }

                        } label: {
                            Label("source_control.tag", systemImage: "tag")
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
                        .font(.system(size: 17))
                        .foregroundColor(Color.init(id: "activityBar.foreground"))
                        .padding(5)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .hoverEffect(.highlight)
                        .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20)
                }
                .onAppear {
                    Task {
                        guard let gitServiceProvider = App.workSpaceStorage.gitServiceProvider
                        else {
                            return
                        }
                        let remotes = try await gitServiceProvider.remotes()
                        let remoteBranches = try await gitServiceProvider.remoteBranches()
                        let localBranches = try await gitServiceProvider.localBranches()
                        let tags = try await gitServiceProvider.tags()
                        await MainActor.run {
                            self.remotes = remotes
                            self.remoteBranches = remoteBranches
                            self.localBranches = localBranches
                            self.tags = tags
                        }
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
