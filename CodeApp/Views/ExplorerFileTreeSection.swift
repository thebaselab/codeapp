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

    var body: some View {
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
    }
}
