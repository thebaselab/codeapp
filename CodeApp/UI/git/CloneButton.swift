//
//  CloneButton.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import SwiftUI

struct CloneButton: View {

    @EnvironmentObject var App: MainApp
    @State var item: GitHubSearchManager.item

    var body: some View {
        Text("Clone")
            .foregroundColor(.white)
            .lineLimit(1)
            .font(.system(size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Color.init(id: "button.background")
            )
            .cornerRadius(10)
            .onTapGesture {

                do {
                    let repo = item.name
                    guard
                        let dirURL = URL(
                            string: App.workSpaceStorage.currentDirectory
                                .url)?.appendingPathComponent(
                                repo, isDirectory: true)
                    else {
                        return
                    }
                    try FileManager.default.createDirectory(
                        atPath: dirURL.path,
                        withIntermediateDirectories: true, attributes: nil)

                    guard let gitURL = URL(string: item.clone_url) else {
                        App.notificationManager.showErrorMessage(
                            "Invalid URL")
                        return
                    }
                    let progress = Progress(totalUnitCount: 100)
                    App.notificationManager.postProgressNotification(
                        title: "Cloning into \(repo)", progress: progress)

                    App.workSpaceStorage.gitServiceProvider?.clone(
                        from: gitURL, to: dirURL, progress: progress,
                        error: {
                            App.notificationManager.showErrorMessage(
                                "Clone error: \($0.localizedDescription)")
                        }
                    ) {
                        App.reloadDirectory()
                        App.notificationManager.postActionNotification(
                            title: "Clone succeeded", level: .success,
                            primary: { App.loadFolder(url: dirURL) },
                            primaryTitle: "Open Folder", source: repo)
                    }
                } catch {
                    App.notificationManager.showErrorMessage(
                        "Clone error: \(error.localizedDescription)")
                }
            }

    }
}
