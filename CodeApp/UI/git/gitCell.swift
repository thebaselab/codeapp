//
//  gitCell.swift
//  Code App
//
//  Created by Ken Chung on 8/12/2020.
//

import SwiftGit2
import SwiftUI

struct GitCell_controls: View {
    @EnvironmentObject var App: MainApp
    var status: Diff.Status
    var itemUrl: URL

    var body: some View {
        switch status {
        case .indexModified, .indexNew, .indexDeleted:
            Image(systemName: "minus")
                .padding(2)
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .onTapGesture {
                    do {
                        try App.gitServiceProvider?.unstage(paths: [
                            itemUrl.absoluteString.removingPercentEncoding!
                        ])
                        App.git_status()
                    } catch {
                        App.notificationManager.showErrorMessage(error.localizedDescription)
                    }
                }
                .hoverEffect(.highlight)
        case .workTreeModified, .workTreeNew, .workTreeDeleted:
            if status != .workTreeNew {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12))
                    .padding(2)
                    .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .onTapGesture {
                        if status == .workTreeModified {
                            App.gitServiceProvider?.previous(
                                path: itemUrl.absoluteString.removingPercentEncoding!,
                                error: {
                                    App.notificationManager.showErrorMessage(
                                        $0.localizedDescription)
                                }
                            ) { content in
                                DispatchQueue.main.async {

                                    do {
                                        try content.write(
                                            to: itemUrl, atomically: true, encoding: .utf8)
                                        App.git_status()
                                        App.notificationManager.showInformationMessage(
                                            "Revert succeeded")
                                    } catch {
                                        App.notificationManager.showErrorMessage(
                                            error.localizedDescription)
                                    }
                                }

                            }
                        } else {
                            do {
                                try App.gitServiceProvider?.checkout(paths: [
                                    itemUrl.absoluteString.removingPercentEncoding!
                                ])
                                App.git_status()
                            } catch {
                                App.notificationManager.showErrorMessage(error.localizedDescription)
                            }
                        }

                    }
                    .hoverEffect(.highlight)
            }
            Image(systemName: "plus")
                .padding(2)
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .onTapGesture {
                    do {
                        try App.gitServiceProvider?.stage(paths: [
                            itemUrl.absoluteString.removingPercentEncoding!.removingPercentEncoding!
                        ])
                        App.git_status()
                    } catch {
                        App.notificationManager.showErrorMessage(error.localizedDescription)
                    }
                }
                .hoverEffect(.highlight)
        default:
            Spacer()
        }
    }
}

struct GitCell: View {

    @EnvironmentObject var App: MainApp
    @State var itemUrl: URL
    @State var isIndex: Bool

    var body: some View {
        Button(action: {
            if !isIndex,
                let status =
                    (isIndex ? App.indexedResources[itemUrl] : App.workingResources[itemUrl]),
                status != .workTreeNew
            {
                App.compareWithPrevious(url: itemUrl)
            }
        }) {
            ZStack {

                if itemUrl.absoluteString == App.activeEditor?.url {
                    Color.init(id: "list.inactiveSelectionBackground").cornerRadius(10.0)
                }

                HStack {
                    fileIcon(
                        url: itemUrl.absoluteString, iconSize: 14, type: EditorInstance.tabType.file
                    )

                    if let status =
                        (isIndex ? App.indexedResources[itemUrl] : App.workingResources[itemUrl]),
                        let name = editorDisplayName(
                            editor: EditorInstance(
                                url: itemUrl.absoluteString, content: "", type: .file))
                    {
                        switch status {
                        case .workTreeModified, .indexModified:
                            Text(name)
                                .foregroundColor(Color.init("git.modified"))
                                .font(.system(size: 14, weight: .light))
                            //                                if !(itemUrl.deletingLastPathComponent().absoluteString == App.currentFolder.url){
                            //                                    Text(itemUrl.deletingLastPathComponent().lastPathComponent.removingPercentEncoding!)
                            //                                        .foregroundColor(.gray)
                            //                                        .font(.system(size: 12, weight: .light))
                            //                                }
                            Spacer()
                            GitCell_controls(status: status, itemUrl: itemUrl)
                            Text("M")
                                .foregroundColor(Color.init("git.modified"))
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 5)
                        case .workTreeNew:
                            Text(name)
                                .foregroundColor(Color.init("git.untracked"))
                                .font(.system(size: 14, weight: .light))
                            Spacer()
                            GitCell_controls(status: status, itemUrl: itemUrl)
                            Text("U")
                                .foregroundColor(Color.init("git.untracked"))
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 5)
                        case .workTreeDeleted, .indexDeleted:
                            Text(name)
                                .foregroundColor(Color.init("git.deleted"))
                                .font(.system(size: 14, weight: .light))
                            Spacer()
                            GitCell_controls(status: status, itemUrl: itemUrl)
                            Text("D")
                                .foregroundColor(Color.init("git.deleted"))
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 5)
                        case .indexNew:
                            Text(name)
                                .foregroundColor(Color.init("git.added"))
                                .font(.system(size: 14, weight: .light))
                            Spacer()
                            GitCell_controls(status: status, itemUrl: itemUrl)
                            Text("A")
                                .foregroundColor(Color.init("git.added"))
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 5)
                        default:
                            Text(name)
                                .font(.system(size: 14, weight: .light))
                            Spacer()
                            GitCell_controls(status: status, itemUrl: itemUrl)
                            Text("X")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 5)
                        }

                    } else {
                        Spacer()
                    }

                }.padding(5)  //.padding(.leading, 5)
            }
        }.buttonStyle(NoAnim())
        //        .contextMenu {
        //
        //            Button(action: {
        //                openSharedFilesApp(urlString: URL(string: item.url)!.deletingLastPathComponent().absoluteString)
        //            }){
        //                Text(NSLocalizedString("Show in Files App", comment: ""))
        //                Image(systemName: "folder")
        //            }
        //
        //            Button(action: {
        //                let pasteboard = UIPasteboard.general
        //                pasteboard.string = item.url.replacingOccurrences(of:App.currentFolder.url, with: "")
        //            }){
        //                Text(NSLocalizedString("Copy Relative Path", comment: ""))
        //                Image(systemName: "link")
        //            }
        //
        //            Button(action: {
        //                if let destination = URL(string: item.url) {
        //                    do {
        //                        try FileManager.default.trashItem(at: destination, resultingItemURL: nil)
        //
        //                        App.closeEditor(url: item.url, type: item.type)
        //
        //                    } catch let error as NSError {
        //                        print("Error: \(error.domain)")
        //                    }
        //                }
        //
        //            }) {
        //                Text(NSLocalizedString("Delete", comment: ""))
        //                Image(systemName: "trash")
        //            }.foregroundColor(.red)
        //
        //        }
    }
}
