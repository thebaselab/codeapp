//
//  SourceControlContainer.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftGit2
import SwiftUI

struct SourceControlContainer: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var stateManager: MainStateManager
    @EnvironmentObject var alertManager: AlertManager

    @AppStorage("communityTemplatesEnabled") var communityTemplatesEnabled = true
    @State var showsPrompt = false

    func onInitializeRepository() async throws {
        guard let serviceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }
        do {
            try await serviceProvider.createRepository()
            App.notificationManager.showInformationMessage(
                "source_control.repository_initialized")
            App.git_status()
        } catch {
            App.notificationManager.showErrorMessage(
                error.localizedDescription
            )
        }
    }

    func onCommit() async throws {
        guard let serviceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }
        if serviceProvider.requiresSignature {
            throw SourceControlError.authorIdentityMissing
        } else if App.gitTracks.isEmpty {
            App.notificationManager.showWarningMessage(
                "errors.source_control.no_staged_changes")
        } else if App.commitMessage.isEmpty {
            App.notificationManager.showWarningMessage(
                "errors.source_control.empty_commit_message")
        } else {
            do {
                try await serviceProvider.commit(message: App.commitMessage)
                App.notificationManager.showInformationMessage(
                    "source_control.commit_succeeded")
            } catch {
                App.notificationManager.showErrorMessage(error.localizedDescription)
            }
            App.git_status()
            App.commitMessage = ""
            App.monacoInstance.invalidateDecorations()
        }
    }

    func onPush(remote: Remote) async throws {
        guard let serviceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }

        let progress = Progress(totalUnitCount: 100)
        progress.localizedDescription = NSLocalizedString(
            "source_control.uploading_objects", comment: "")

        App.notificationManager.postProgressNotification(
            title: "source_control.pushing_to_remote", progress: progress)

        do {
            let currentBranch = try await serviceProvider.currentBranch()
            try await serviceProvider.push(
                branch: currentBranch, remote: remote, progress: progress)
            App.notificationManager.showInformationMessage(
                "source_control.push_succeeded")
            App.git_status()
        } catch {
            let error = error as NSError
            if error.code == LibGit2ErrorClass._GIT_ERROR_HTTP {
                App.notificationManager.postActionNotification(
                    title:
                        "errors.source_control.authentication_failed",
                    level: .error,
                    primary: { showsPrompt = true }, primaryTitle: "common.configure",
                    source: "source_control.title")
            } else {
                App.notificationManager.showErrorMessage(
                    error.localizedDescription)
            }
            throw error
        }
    }

    func onFetch(remote: Remote) async throws {
        guard let serviceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }

        try await App.notificationManager.withAsyncNotification(
            title: "source_control.fetching_from_origin"
        ) {
            do {
                try await serviceProvider.fetch(remote: remote)
                App.notificationManager.showInformationMessage(
                    "source_control.fetch_succeeded")
                App.git_status()
            } catch {
                App.notificationManager.showErrorMessage(error.localizedDescription)
                throw error
            }
        }
    }

    func onStage(paths: [String]) throws {
        guard let serviceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }
        guard paths.count > 0 else {
            return
        }
        Task {
            do {
                try await serviceProvider.stage(paths: paths)
                App.git_status()
            } catch {
                App.notificationManager.showErrorMessage(error.localizedDescription)
                throw error
            }
        }
    }

    func onStageAllChanges() throws {
        let paths = App.workingResources.keys.map {
            $0.absoluteString.removingPercentEncoding!
        }
        try onStage(paths: paths)
    }

    func onClone(urlString: String) async throws {
        guard let serviceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }
        guard let gitURL = URL(string: urlString) else {
            App.notificationManager.showErrorMessage("errors.source_control.invalid_url")
            throw SourceControlError.invalidURL
        }

        let repo = gitURL.deletingPathExtension().lastPathComponent
        guard
            let dirURL = URL(
                string: App.workSpaceStorage.currentDirectory.url)?
                .appendingPathComponent(repo, isDirectory: true)
        else {
            throw SourceControlError.gitServiceProviderUnavailable
        }

        try FileManager.default.createDirectory(
            atPath: dirURL.path, withIntermediateDirectories: true,
            attributes: nil)

        let progress = Progress(totalUnitCount: 100)
        App.notificationManager.postProgressNotification(
            title: "source_control.cloning_into",
            progress: progress,
            gitURL.absoluteString)

        do {
            try await serviceProvider.clone(from: gitURL, to: dirURL, progress: progress)
            App.notificationManager.postActionNotification(
                title: "source_control.clone_succeeded", level: .success,
                primary: {
                    App.loadFolder(url: dirURL)
                }, primaryTitle: "common.open_folder", source: repo)
        } catch {
            let error = error as NSError
            if error.code == LibGit2ErrorClass._GIT_ERROR_HTTP {
                App.notificationManager.postActionNotification(
                    title:
                        "errors.source_control.clone_authentication_failed",
                    level: .error,
                    primary: {
                        showsPrompt = true
                    }, primaryTitle: "common.configure",
                    source: "source_control.title")
            } else {
                App.notificationManager.showErrorMessage(
                    "source_control.error", error.localizedDescription)
            }
            throw error
        }
    }

    func onUnstage(urlString: String) throws {
        guard let serviceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }
        Task {
            do {
                try await serviceProvider.unstage(paths: [urlString])
                App.git_status()
            } catch {
                App.notificationManager.showErrorMessage(error.localizedDescription)
                throw error
            }
        }

    }

    func onRevert(urlString: String, confirm: Bool = false) async throws {
        guard let serviceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }
        guard let fileURL = URL(string: urlString) else {
            App.notificationManager.showErrorMessage("errors.source_control.invalid_url")
            throw SourceControlError.invalidURL
        }

        if !confirm {
            alertManager.showAlert(
                title: "source_control.confirm_revert \(fileURL.lastPathComponent)",
                content: AnyView(
                    Group {
                        Button("common.revert", role: .destructive) {
                            Task {
                                try await onRevert(urlString: urlString, confirm: true)
                            }
                        }
                        Button("common.cancel", role: .cancel) {}
                    }
                )
            )
            return
        }

        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)

        if !fileExists {
            do {
                try await serviceProvider.checkout(paths: [fileURL.absoluteString])
                App.git_status()
            } catch {
                App.notificationManager.showErrorMessage(error.localizedDescription)
                throw error
            }
            return
        }

        do {
            let previousContent = try await serviceProvider.previous(path: fileURL.absoluteString)
            try previousContent.write(to: fileURL, atomically: true, encoding: .utf8)
            App.git_status()
            App.notificationManager.showInformationMessage("source_control.revert_succeeded")
        } catch {
            App.notificationManager.showErrorMessage(error.localizedDescription)
            throw error
        }
    }

    func onShowChangesInDiffEditor(urlString: String) throws {
        guard let fileURL = URL(string: urlString) else {
            App.notificationManager.showErrorMessage("errors.source_control.invalid_url")
            throw SourceControlError.invalidURL
        }
        Task {
            do {
                try await App.notificationManager.withAsyncNotification(
                    title: "Retrieving changes",
                    task: {
                        try await App.compareWithPrevious(url: fileURL)
                    })
            } catch {
                App.notificationManager.showErrorMessage(error.localizedDescription)
            }
        }
    }

    func onPull(branch: Branch, remote: Remote) async throws {
        guard let serviceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }

        try await App.notificationManager.withAsyncNotification(
            title: "source_control.pulling_from_remote"
        ) {
            do {
                try await serviceProvider.pull(branch: branch, remote: remote)
                App.notificationManager.showInformationMessage("source_control.pull_succeeded")
            } catch {
                App.notificationManager.showErrorMessage(error.localizedDescription)
            }

        }
    }

    var body: some View {
        VStack(spacing: 0) {
            //            InfinityProgressView(enabled: stateManager.gitServiceIsBusy)

            List {
                Group {
                    if App.workSpaceStorage.gitServiceProvider == nil {
                        SourceControlUnsupportedSection()
                    } else if App.gitTracks.count > 0 || App.branch != "" {
                        SourceControlSection(
                            onCommit: onCommit,
                            onPush: onPush,
                            onFetch: onFetch,
                            onStageAllChanges: onStageAllChanges,
                            onUnstage: onUnstage,
                            onRevert: onRevert,
                            onStage: onStage,
                            onShowChangesInDiffEditor: onShowChangesInDiffEditor,
                            onPull: onPull
                        )
                    } else {
                        SourceControlEmptySection(onInitializeRepository: onInitializeRepository)
                        SourceControlCloneSection(onClone: onClone)
                        if communityTemplatesEnabled {
                            SourceControlTemplateSection(onClone: onClone)
                        }
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .environment(\.defaultMinListRowHeight, 10)
        .listStyle(SidebarListStyle())
        .sheet(
            isPresented: $showsPrompt,
            content: {
                NavigationView {
                    SourceControlAuthenticationConfiguration()
                }
            })
    }
}
