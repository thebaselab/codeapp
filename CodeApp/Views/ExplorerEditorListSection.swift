//
//  ExplorerEditorsSection.swift
//  Code
//
//  Created by Ken Chung on 12/11/2022.
//

import SwiftUI

struct ExplorerEditorListSection: View {

    @EnvironmentObject var App: MainApp

    let onOpenNewFile: () -> Void
    let onPickNewDirectory: () -> Void

    var body: some View {
        Section(
            header:
                Text("Open Editors")
        ) {
            if App.editors.isEmpty {
                SideBarButton("New File") {
                    onOpenNewFile()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                SideBarButton("Open Folder") {
                    onPickNewDirectory()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            ForEach(App.editors) { item in
                EditorCell(item: item)
                    .frame(height: 16)
                    .listRowBackground(
                        item.url == App.activeEditor?.url
                            ? Color.init(id: "list.inactiveSelectionBackground")
                                .cornerRadius(10.0)
                            : Color.clear.cornerRadius(10.0)
                    )
                    .listRowSeparator(.hidden)
            }
        }
    }
}

private struct EditorCell: View {

    @EnvironmentObject var App: MainApp
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @State var item: EditorInstance

    func onOpenEditor() {
        App.openEditor(urlString: item.url, type: item.type)
    }

    func onOpenInFilesApp() {
        openSharedFilesApp(
            urlString: URL(string: item.url)!.deletingLastPathComponent().absoluteString
        )
    }

    func onCopyRelativePath() {
        let pasteboard = UIPasteboard.general
        guard let targetURL = URL(string: item.url),
            let baseURL = URL(string: App.currentURL())
        else {
            return
        }
        pasteboard.string = targetURL.relativePath(from: baseURL)
    }

    func onTrashEditor() {
        guard let url = URL(string: item.url) else {
            return
        }
        App.trashItem(url: url)
    }

    var body: some View {
        Button(action: onOpenEditor) {
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
            Button(action: onOpenInFilesApp) {
                Text("Show in Files App")
                Image(systemName: "folder")
            }

            Button(action: onCopyRelativePath) {
                Text("Copy Relative Path")
                Image(systemName: "link")
            }

            if URL(string: item.url) != nil {
                Button(action: onTrashEditor) {
                    Text("Delete")
                    Image(systemName: "trash")
                }.foregroundColor(.red)
            }
        }
    }
}
