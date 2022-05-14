//
//  cell.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

struct cell: View {

    @EnvironmentObject var App: MainApp
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @State var item: EditorInstance

    var body: some View {
        Button(action: {
            App.openEditor(urlString: item.url, type: item.type)
        }) {
            ZStack {

                HStack {
                    fileIcon(url: item.url, iconSize: 14, type: item.type)

                    if item.type == .file,
                        let status = App.gitTracks[URL(string: item.url)!.standardizedFileURL]
                    {
                        FileDisplayName(gitStatus: status, name: editorDisplayName(editor: item))
                    } else {
                        FileDisplayName(gitStatus: nil, name: editorDisplayName(editor: item))
                    }

                }.padding(5)
            }
        }
        .if(item.url == App.activeEditor?.url && item.type == App.activeEditor?.type) { view in
            view.listRowBackground(
                Color.init(id: "list.inactiveSelectionBackground")
                    .cornerRadius(10.0))
        }
        .contextMenu {

            Button(action: {
                openSharedFilesApp(
                    urlString: URL(string: item.url)!.deletingLastPathComponent().absoluteString
                )
            }) {
                Text("Show in Files App")
                Image(systemName: "folder")
            }

            Button(action: {
                let pasteboard = UIPasteboard.general
                guard let targetURL = URL(string: item.url),
                    let baseURL = URL(string: App.currentURL())
                else {
                    return
                }
                pasteboard.string = targetURL.relativePath(from: baseURL)
            }) {
                Text("Copy Relative Path")
                Image(systemName: "link")
            }

            if let url = URL(string: item.url) {
                Button(action: {
                    App.trashItem(url: url)
                }) {
                    Text("Delete")
                    Image(systemName: "trash")
                }.foregroundColor(.red)
            }

        }
    }
}
