//
//  CloneRepositorySection.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import SwiftUI

struct CloneRepositorySection: View {

    @EnvironmentObject var App: MainApp

    @State var gitURL: String = ""

    var body: some View {
        Section(
            header:
                HStack {
                    Text(NSLocalizedString("Clone Repository", comment: ""))
                        .foregroundColor(Color.init("BW"))
                }

        ) {

            if App.searchManager.errorMessage != "" {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(App.searchManager.errorMessage).font(
                        .system(size: 12, weight: .light))
                }.foregroundColor(.gray)

            }

            HStack {
                Image(systemName: "link")
                    .foregroundColor(.gray)
                    .font(.subheadline)

                TextField(
                    "URL (HTTPS)", text: $gitURL,
                    onCommit: {
                        do {
                            guard let gitURL = URL(string: self.gitURL) else {
                                App.notificationManager.showErrorMessage("Invalid URL")
                                return
                            }

                            let repo = gitURL.deletingPathExtension().lastPathComponent
                            guard
                                let dirURL = URL(
                                    string: App.workSpaceStorage.currentDirectory.url)?
                                    .appendingPathComponent(repo, isDirectory: true)
                            else {
                                return
                            }
                            try FileManager.default.createDirectory(
                                atPath: dirURL.path, withIntermediateDirectories: true,
                                attributes: nil)

                            let progress = Progress(totalUnitCount: 100)
                            App.notificationManager.postProgressNotification(
                                title: "Cloning into \(gitURL.absoluteString)",
                                progress: progress)

                            App.workSpaceStorage.gitServiceProvider?.clone(
                                from: gitURL, to: dirURL, progress: progress,
                                error: {
                                    App.notificationManager.showErrorMessage(
                                        "Clone error: \($0.localizedDescription)")
                                }
                            ) {
                                self.gitURL = ""
                                App.notificationManager.postActionNotification(
                                    title: "Clone succeeded", level: .success,
                                    primary: {
                                        App.loadFolder(url: dirURL)
                                    }, primaryTitle: "Open Folder", source: repo)
                            }
                        } catch {
                            App.notificationManager.showErrorMessage(
                                "Clone error: \(error.localizedDescription)")
                        }
                    }
                )
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)

                Spacer()

            }.padding(7)
                .background(Color.init(id: "input.background"))
                .cornerRadius(15)

            DescriptionText("Example: https://github.com/thebaselab/codeapp.git")

            GitHubSearchView()
        }
    }
}
