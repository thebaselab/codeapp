//
//  FileFolderCell.swift
//  Code
//
//  Created by Ken Chung on 24/4/2022.
//

import SwiftUI

struct FileFolderCell: View {
    @EnvironmentObject var App: MainApp
    let item: WorkSpaceStorage.fileItemRepresentable

    var body: some View {
        if item.subFolderItems != nil {
            FolderCell(item: item)
                .frame(height: 16)
                .onDrag{
                    guard let url = item._url else {
                        return NSItemProvider()
                    }
                    let itemProvider = NSItemProvider()
                    itemProvider.suggestedName = url.lastPathComponent
                    itemProvider.registerFileRepresentation(forTypeIdentifier: "public.folder", visibility: .all) {
                        $0(url, false, nil)
                        return nil
                    }
                    return itemProvider
                }
        } else {
            FileCell(item: item)
                .frame(height: 16)
                .onDrag{
                    guard let url = item._url, let provider = NSItemProvider(contentsOf: url) else {
                        return NSItemProvider()
                    }
                    provider.suggestedName = url.lastPathComponent
                    return provider
                }
        }
    }
}
