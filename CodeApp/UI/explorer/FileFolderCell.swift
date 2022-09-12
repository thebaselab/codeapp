//
//  FileFolderCell.swift
//  Code
//
//  Created by Ken Chung on 24/4/2022.
//

import SwiftUI
import UniformTypeIdentifiers

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
                .onDrop(of: [.folder, .item], isTargeted: nil, perform: { providers in
                    if let provider = providers.first {
                            provider.loadItem(forTypeIdentifier: UTType.item.identifier){ data, error in
                                if let at = data as? URL, let to = item._url?.appendingPathComponent(at.lastPathComponent, conformingTo: .item) {
                                    App.workSpaceStorage.copyItem(at: at, to: to, completionHandler: { error in
                                        if let error = error {
                                            App.notificationManager.showErrorMessage(error.localizedDescription)
                                        }
                                    })
                                }
                            }
                    }
                    return true
                })
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
