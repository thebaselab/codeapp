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
    @State var showsPrompt = false
    func onInitializeRepository() async throws {
        guard let serviceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }
        serviceProvider.initialize(error: { err in
            App.notificationManager.showErrorMessage(
                err.localizedDescription
            )
        }) {
            App.notificationManager.showInformationMessage(
                "Repository initialized")
            App.git_status()
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
                "There are no staged changes")
        } else if App.commitMessage.isEmpty {
            App.notificationManager.showWarningMessage(
                "Commit message cannot be empty")
        } else {
            serviceProvider.commit(
                message: App.commitMessage,
                error: {
                    App.notificationManager.showErrorMessage(
                        $0.localizedDescription)
                }
            ) {
                App.git_status()
                DispatchQueue.main.async {
                    App.commitMessage = ""
                    App.monacoInstance.invalidateDecorations()
                }
                App.notificationManager.showInformationMessage(
                    "Commit succeeded")
            }
        }
    }

    func onPush(remote: Remote) async throws {
        guard let serviceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }

        let progress = Progress(totalUnitCount: 100)
        progress.localizedDescription = "Uploading objects"

        App.notificationManager.postProgressNotification(
            title: "Pushing to remote", progress: progress)

        return try await withCheckedThrowingContinuation { continuation in
            serviceProvider.push(
                error: {
                    if $0.code == GitErrorCode.GIT_EAUTH.rawValue {
                        App.notificationManager.postActionNotification(
                            title:
                                "Authentication failed: You might need to configure your git credentials.",
                            level: .error,
                            primary: {

                                showsPrompt = true

                            }, primaryTitle: "Configure", source: "Source Control")
                    } else {
                        App.notificationManager.showErrorMessage(
                            $0.localizedDescription)
                    }

                    continuation.resume(throwing: $0)
                }, remote: remote.name, progress: progress
            ) {
                App.notificationManager.showInformationMessage(
                    "Push succeeded")
                App.git_status()

                continuation.resume()
            }
        }
    }

    func onFetch() async throws {
        guard let serviceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }

        App.notificationManager.showInformationMessage(
            "Fetching from origin")

        return try await withCheckedThrowingContinuation { continuation in
            serviceProvider.fetch(error: {
                App.notificationManager.showErrorMessage(
                    $0.localizedDescription)
                continuation.resume(throwing: $0)
            }) {
                App.notificationManager.showInformationMessage(
                    "Fetch succeeded")
                App.git_status()

                continuation.resume()
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

        do {
            try serviceProvider.stage(paths: paths)
            App.git_status()
        } catch {
            App.notificationManager.showErrorMessage(error.localizedDescription)
            throw error
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
            App.notificationManager.showErrorMessage("Invalid URL")
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
            title: "Cloning into \(gitURL.absoluteString)",
            progress: progress)

        return try await withCheckedThrowingContinuation { continuation in
            serviceProvider.clone(
                from: gitURL, to: dirURL, progress: progress,
                error: {
                    if $0.localizedDescription
                        == "could not find appropriate mechanism for credentials"
                    {
                        App.notificationManager.postActionNotification(
                            title:
                                "Authentication failed: You might need to configure your git credentials.",
                            level: .error,
                            primary: {
                                showsPrompt = true
                            }, primaryTitle: "Configure",
                            source: "Source Control")
                    } else {
                        App.notificationManager.showErrorMessage(
                            "Clone error: \($0.localizedDescription)")
                    }
                    continuation.resume(throwing: $0)
                }
            ) {
                App.notificationManager.postActionNotification(
                    title: "Clone succeeded", level: .success,
                    primary: {
                        App.loadFolder(url: dirURL)
                    }, primaryTitle: "Open Folder", source: repo)
                continuation.resume()
            }
        }
    }

    func onUnstage(urlString: String) throws {
        guard let serviceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }

        do {
            try serviceProvider.unstage(paths: [urlString])
            App.git_status()
        } catch {
            App.notificationManager.showErrorMessage(error.localizedDescription)
            throw error
        }
    }

    func onRevert(urlString: String) async throws {
        guard let serviceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }
        guard let fileURL = URL(string: urlString) else {
            App.notificationManager.showErrorMessage("Invalid URL")
            throw SourceControlError.invalidURL
        }

        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)

        if !fileExists {
            do {
                try serviceProvider.checkout(paths: [fileURL.absoluteString])
                App.git_status()
            } catch {
                App.notificationManager.showErrorMessage(error.localizedDescription)
                throw error
            }
            return
        }

        return try await withCheckedThrowingContinuation { continuation in
            serviceProvider.previous(
                path: fileURL.absoluteString,
                error: {
                    App.notificationManager.showErrorMessage(
                        $0.localizedDescription)
                    continuation.resume(throwing: $0)
                }
            ) { content in
                do {
                    try content.write(
                        to: fileURL, atomically: true, encoding: .utf8)
                    App.git_status()
                    App.notificationManager.showInformationMessage(
                        "Revert succeeded")
                    continuation.resume()
                } catch {
                    App.notificationManager.showErrorMessage(
                        error.localizedDescription)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func onShowChangesInDiffEditor(urlString: String) throws {
        guard let fileURL = URL(string: urlString) else {
            App.notificationManager.showErrorMessage("Invalid URL")
            throw SourceControlError.invalidURL
        }
        App.compareWithPrevious(url: fileURL)
    }

    var body: some View {
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
                        onShowChangesInDiffEditor: onShowChangesInDiffEditor
                    )
                } else {
                    SourceControlEmptySection(onInitializeRepository: onInitializeRepository)
                    SourceControlCloneSection(onClone: onClone)
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .environment(\.defaultMinListRowHeight, 10)
        .listStyle(SidebarListStyle())
        .sheet(
            isPresented: $showsPrompt,
            content: {
                SourceControlAuthenticationConfiguration()
            })
    }
}
