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
        } else {
            FileCell(item: item)
                .frame(height: 16)
        }
    }
}
