//
//  cell.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

struct cell: View {

    @EnvironmentObject var App: MainApp
    @State var item: EditorInstance

    var body: some View {
        Button(action: {
            App.openEditor(urlString: item.url, type: item.type)
        }) {
            ZStack {
                if item.url == App.activeEditor?.url && item.type == App.activeEditor?.type {
                    Color.init(id: "list.inactiveSelectionBackground").cornerRadius(10.0)
                } else {
                    Color.init(id: "sideBar.background")
                }

                HStack {
                    fileIcon(url: item.url, iconSize: 14, type: item.type)

                    if item.type == .file {
                        if let status = App.gitTracks[URL(string: item.url)!.standardizedFileURL] {
                            switch status {
                            case .workTreeModified, .indexModified:
                                Text(editorDisplayName(editor: item))
                                    .foregroundColor(Color.init("git.modified"))
                                    .font(.system(size: 14, weight: .light))
                                Spacer()
                                Text("M")
                                    .foregroundColor(Color.init("git.modified"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 5)
                            case .workTreeNew:
                                Text(editorDisplayName(editor: item))
                                    .foregroundColor(Color.init("git.untracked"))
                                    .font(.system(size: 14, weight: .light))
                                Spacer()
                                Text("U")
                                    .foregroundColor(Color.init("git.untracked"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 5)
                            case .indexDeleted, .workTreeDeleted:
                                Text(editorDisplayName(editor: item))
                                    .foregroundColor(Color.init("git.deleted"))
                                    .font(.system(size: 14, weight: .light))
                                Spacer()
                                Text("D")
                                    .foregroundColor(Color.init("git.deleted"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 5)
                            case .indexNew:
                                Text(editorDisplayName(editor: item))
                                    .foregroundColor(Color.init("git.added"))
                                    .font(.system(size: 14, weight: .light))
                                Spacer()
                                Text("A")
                                    .foregroundColor(Color.init("git.added"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 5)
                            default:
                                Spacer()
                            }

                        } else {
                            Text(editorDisplayName(editor: item))
                                .foregroundColor(Color.init(id: "list.inactiveSelectionForeground"))
                                .font(.system(size: 14, weight: .light))
                            Spacer()
                        }
                    } else {
                        Text(editorDisplayName(editor: item))
                            .foregroundColor(Color.init(id: "list.inactiveSelectionForeground"))
                            .font(.system(size: 14, weight: .light))
                        Spacer()
                    }

                }.padding(5)  //.padding(.leading, 5)
            }
        }.buttonStyle(NoAnim())
            .contextMenu {

                Button(action: {
                    openSharedFilesApp(
                        urlString: URL(string: item.url)!.deletingLastPathComponent().absoluteString
                    )
                }) {
                    Text(NSLocalizedString("Show in Files App", comment: ""))
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
                    Text(NSLocalizedString("Copy Relative Path", comment: ""))
                    Image(systemName: "link")
                }

                if let url = URL(string: item.url) {
                    Button(action: {
                        App.trashItem(url: url)
                    }) {
                        Text(NSLocalizedString("Delete", comment: ""))
                        Image(systemName: "trash")
                    }.foregroundColor(.red)
                }

            }
    }
}
