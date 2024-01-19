//
//  ExplorerFileTreeSection.swift
//  Code
//
//  Created by Ken Chung on 12/11/2022.
//

import SwiftUI

struct ExplorerFileTreeSection: View {

    @EnvironmentObject var App: MainApp
    @AppStorage("explorer.showHiddenFiles") var showHiddenFiles: Bool = false

    let searchString: String
    let onDrag: (WorkSpaceStorage.FileItemRepresentable) -> NSItemProvider
    let onDropToFolder: (WorkSpaceStorage.FileItemRepresentable, [NSItemProvider]) -> Bool

    func foldersWithFilter(folder: [WorkSpaceStorage.FileItemRepresentable]?) -> [WorkSpaceStorage
        .FileItemRepresentable]
    {

        var result = [WorkSpaceStorage.FileItemRepresentable]()

        for item in folder ?? [WorkSpaceStorage.FileItemRepresentable]() {
            if searchString == "" {
                result.append(item)
                continue
            }
            if item.subFolderItems == nil
                && item.name.lowercased().contains(searchString.lowercased())
            {
                result.append(item)
                continue
            }
            if item.subFolderItems != nil {
                var temp = item
                temp.subFolderItems = foldersWithFilter(folder: item.subFolderItems)
                if temp.subFolderItems?.count != 0 {
                    result.append(temp)
                }
            }
        }

        if !showHiddenFiles {
            var finalResult = [WorkSpaceStorage.FileItemRepresentable]()
            for item in result {
                if item.name.hasPrefix(".") && !item.name.hasSuffix("icloud") {
                    continue
                }
                if item.subFolderItems != nil {
                    var temp = item
                    temp.subFolderItems = temp.subFolderItems?.filter { a in
                        return !a.name.hasPrefix(".")
                    }
                    finalResult.append(temp)
                    continue
                }
                finalResult.append(item)
            }
            return finalResult
        }

        return result
    }

    func buildContextMenu(item: WorkSpaceStorage.FileItemRepresentable)
        -> UIContextMenuConfiguration
    {

        let ACTION_OPEN_IN_TAB = UIAction(
            title: "Open in Tab", image: UIImage(systemName: "doc.plaintext")!
        ) { _ in
            if let url = item._url {
                App.openFile(url: url, alwaysInNewTab: true)
            }
        }
        let ACTION_SHOW_IN_FILEAPP = UIAction(
            title: "Show in Files App", image: UIImage(systemName: "folder")!
        ) { _ in
            openSharedFilesApp(
                urlString: URL(string: item.url)!.deletingLastPathComponent()
                    .absoluteString
            )
        }
        let ACTION_RENAME = UIAction(title: "Rename", image: UIImage(systemName: "pencil")!) { _ in
            // TODO
        }
        let ACTION_DUPLICATE = UIAction(
            title: "Duplicate", image: UIImage(systemName: "plus.square.on.square")!
        ) { _ in
            Task {
                guard let url = item._url else { return }
                try await App.duplicateItem(at: url)
            }
        }
        let ACTION_DELETE = UIAction(title: "Delete", image: UIImage(systemName: "trash")!) { _ in
            guard let url = item._url else { return }
            App.trashItem(url: url)
        }
        let ACTION_COPY_DOWNLOAD = UIAction(
            title: item.url.hasPrefix("file") ? "file.copy" : "file.download",
            image: UIImage(systemName: "folder")!
        ) { _ in
            // TODO
        }

        let ACTION_COPY_RELATIVE_PATH = UIAction(
            title: "Copy Relative Path", image: UIImage(systemName: "link")!
        ) { _ in
            let pasteboard = UIPasteboard.general
            guard let targetURL = URL(string: item.url),
                let baseURL = (App.activeEditor as? EditorInstanceWithURL)?.url
            else {
                return
            }
            pasteboard.string = targetURL.relativePath(from: baseURL)
        }

        let ACTION_NEW_FILE = UIAction(
            title: "New File", image: UIImage(systemName: "doc.badge.plus")!
        ) { _ in
            // TODO
        }

        let ACTION_NEW_FOLDER = UIAction(
            title: "New Folder", image: UIImage(systemName: "folder.badge.plus")!
        ) { _ in
            Task {
                guard let url = item._url else { return }
                try await App.createFolder(at: url)
            }
        }

        let ACTION_ASSIGN_AS_WORKSPACE_FOLDER = UIAction(
            title: "Assign as workspace folder", image: UIImage(systemName: "folder.badge.gear")!
        ) { _ in
            App.loadFolder(url: URL(string: item.url)!)
        }

        let ACTION_SELECT_FOR_COMPARE = UIAction(
            title: "Select for compare", image: UIImage(systemName: "square.split.2x1")!
        ) { _ in
            App.selectedURLForCompare = item._url
        }

        let ACTION_COMPARE_WITH_SELECTED = UIAction(
            title: "Compare with selected", image: UIImage(systemName: "square.split.2x1")!
        ) { _ in
            guard let url = item._url else { return }
            Task {
                do {
                    try await App.compareWithSelected(url: url)
                } catch {
                    App.notificationManager.showErrorMessage(error.localizedDescription)
                }

            }
        }

        let actionProvider: UIContextMenuActionProvider = { _ in
            if item.subFolderItems == nil {
                return UIMenu(
                    children: [
                        ACTION_OPEN_IN_TAB,
                        ACTION_SHOW_IN_FILEAPP,
                        ACTION_RENAME,
                        ACTION_DUPLICATE,
                        ACTION_DELETE,
                        ACTION_COPY_DOWNLOAD,
                        ACTION_COPY_RELATIVE_PATH,
                        ACTION_SELECT_FOR_COMPARE,
                        ACTION_COMPARE_WITH_SELECTED,
                    ])
            } else {
                return UIMenu(
                    children: [
                        ACTION_SHOW_IN_FILEAPP,
                        ACTION_RENAME,
                        ACTION_DUPLICATE,
                        ACTION_DELETE,
                        ACTION_COPY_DOWNLOAD,
                        ACTION_COPY_RELATIVE_PATH,
                        ACTION_NEW_FILE,
                        ACTION_NEW_FOLDER,
                        ACTION_ASSIGN_AS_WORKSPACE_FOLDER,
                    ])
            }

        }
        return UIContextMenuConfiguration(
            identifier: item.url as NSCopying, previewProvider: nil,
            actionProvider: actionProvider)
    }

    var body: some View {
        /*
        Section(
            header:
                Text(
                    App.workSpaceStorage.currentDirectory.name.replacingOccurrences(
                        of: "{default}", with: " "
                    ).removingPercentEncoding!
                ).foregroundColor(Color(id: "sideBarSectionHeader.foreground"))
        ) {
            HierarchyList(
                data: foldersWithFilter(
                    folder: App.workSpaceStorage.currentDirectory.subFolderItems),
                children: \.subFolderItems,
                expandStates: $App.workSpaceStorage.expansionStates,
                rowContent: { item in
                    ExplorerCell(
                        item: item,
                        onDrag: {
                            onDrag(item)
                        },
                        onDropToFolder: { providers in
                            onDropToFolder(item, providers)
                        }
                    )
                    .frame(height: 16)
                    .listRowBackground(
                        item.url == (App.activeEditor as? EditorInstanceWithURL)?.url.absoluteString
                            ? Color.init(id: "list.inactiveSelectionBackground")
                                .cornerRadius(10.0)
                            : Color.clear.cornerRadius(10.0)
                    )
                    .listRowSeparator(.hidden)
                    .id(item.url)
                },
                onDisclose: { id in
                    if let id = id as? String {
                        App.workSpaceStorage.requestDirectoryUpdateAt(id: id)
                    }
                })
        }
         */

        TableView(
            App.workSpaceStorage.currentDirectory,
            children: \WorkSpaceStorage.FileItemRepresentable.subFolderItems,
            cellState: App.workSpaceStorage.cellState,
            expandedCells: $App.workSpaceStorage.expandedCells
        ) { item in
            UIHostingConfiguration {
                HStack {
                    ExplorerCell(
                        item: item,
                        onDrag: {
                            onDrag(item)
                        },
                        onDropToFolder: { providers in
                            onDropToFolder(item, providers)
                        }
                    )
                }
            }.background(Color.init(id: "sideBar.background"))
        }.onExpand { item in
            App.workSpaceStorage.requestDirectoryUpdateAt(id: item.id)
        }.headerText(
            App.workSpaceStorage.currentDirectory.name.replacingOccurrences(
                of: "{default}", with: " "
            ).removingPercentEncoding!
        ).onMove { from, to in
            print("Moving \(from.id) -> \(to.id)")
            guard let fromUrl = from._url,
                let toUrl = to._url?.appending(path: fromUrl.lastPathComponent)
            else {
                return
            }
            Task {
                do {
                    try await App.workSpaceStorage.moveItem(at: fromUrl, to: toUrl)
                } catch {
                    App.notificationManager.showErrorMessage(error.localizedDescription)
                }
            }
        }.onContextMenu {
            buildContextMenu(item: $0)
        }
        .onTabelViewCellDrag(onDrag)
        .padding(.horizontal, 10)
    }
}
