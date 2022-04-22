//
//  FileCellContextMenu.swift
//  Code
//
//  Created by Ken Chung on 19/4/2022.
//

import SwiftUI

struct FileCellContextMenu: View {

    @EnvironmentObject var App: MainApp

    let item: WorkSpaceStorage.fileItemRepresentable

    let onRename: () -> Void
    let onCreateNewFile: () -> Void

    var body: some View {
        Group {

            if item.subFolderItems == nil {
                Button(action: {
                    App.openEditor(urlString: item.url, type: .any, inNewTab: true)
                }) {
                    Text("Open in Tab")
                    Image(systemName: "doc.plaintext")
                }
            }

            Button(action: {
                openSharedFilesApp(
                    urlString: URL(string: item.url)!.deletingLastPathComponent()
                        .absoluteString
                )
            }) {
                Text("Show in Files App")
                Image(systemName: "folder")
            }

            Group {
                Button(action: {
                    onRename()
                }) {
                    Text("Rename")
                    Image(systemName: "pencil")
                }

                Button(action: {
                    App.duplicateItem(from: URL(string: item.url)!)
                }) {
                    Text("Duplicate")
                    Image(systemName: "plus.square.on.square")
                }

                Button(action: {
                    App.trashItem(url: URL(string: item.url)!)
                }) {
                    Text("Delete").foregroundColor(.red)
                    Image(systemName: "trash").foregroundColor(.red)
                }
            }

            Divider()

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

            if item.subFolderItems != nil {
                Button(action: {
                    onCreateNewFile()
                }) {
                    Text("New File")
                    Image(systemName: "doc.badge.plus")
                }

                Button(action: {
                    App.createFolder(urlString: item.url)
                }) {
                    Text("New Folder")
                    Image(systemName: "folder.badge.plus")
                }

                Button(action: {
                    App.loadFolder(url: URL(string: item.url)!)
                }) {
                    Text("Assign as workplace folder")
                    Image(systemName: "folder.badge.gear")
                }
            }

            if item.subFolderItems == nil {
                Button(action: {
                    App.selectedForCompare = item.url
                }) {
                    Text("Select for compare")
                    Image(systemName: "square.split.2x1")
                }

                if App.selectedForCompare != "" && App.selectedForCompare != item.url {
                    Button(action: {
                        App.compareWithSelected(url: item.url)
                    }) {
                        Text("Compare with selected")
                        Image(systemName: "square.split.2x1")
                    }
                }
            }
        }
    }
}
