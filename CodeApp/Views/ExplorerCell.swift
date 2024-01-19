//
//  FileFolderCell.swift
//  Code
//
//  Created by Ken Chung on 24/4/2022.
//

import SwiftUI
import UniformTypeIdentifiers

struct ExplorerCell: View {
    @EnvironmentObject var App: MainApp

    let item: WorkSpaceStorage.FileItemRepresentable
    let onDrag: () -> NSItemProvider
    let onDropToFolder: ([NSItemProvider]) -> Bool

    var body: some View {
        FileCell(item: item)
            .frame(height: 16)
    }
}

private struct FileCell: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var themeManager: ThemeManager
    @State var item: WorkSpaceStorage.FileItemRepresentable
    @State var newname = ""
    @State var showsDirectoryPicker = false
    @FocusState var focusedField: Field?
    @State var isRenaming: Bool = false

    init(item: WorkSpaceStorage.FileItemRepresentable) {
        self.item = item
        self._newname = State.init(initialValue: item.name.removingPercentEncoding!)
    }

    enum Field {
        case rename
    }

    func onRename() {
        focusedField = nil

        Task {
            do {
                try await App.renameFile(
                    url: URL(string: item.url)!, name: newname)
            } catch {
                App.notificationManager.showErrorMessage(error.localizedDescription)
                newname = item.name.removingPercentEncoding!
            }
        }
    }

    var body: some View {

        HStack {
            if item.subFolderItems != nil {
                Image(systemName: "folder")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
                    .frame(width: 14, height: 14)
            } else {
                FileIcon(url: newname, iconSize: 14)
                    .frame(width: 14, height: 14)
            }

            if isRenaming {
                HStack {
                    TextField(item.name.removingPercentEncoding!, text: $newname)
                        .multilineTextAlignment(.leading)
                        .font(.subheadline)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: .rename)
                        .onSubmit(onRename)
                        .onReceive(
                            NotificationCenter.default.publisher(
                                for: UITextField.textDidBeginEditingNotification)
                        ) { obj in
                            if let textField = obj.object as? UITextField {
                                textField.selectedTextRange = textField.textRange(
                                    from: textField.beginningOfDocument,
                                    to: textField.endOfDocument
                                )
                            }
                        }
                        .onChange(of: focusedField) { field in
                            if field == nil {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    isRenaming = false
                                }
                            }
                        }
                    Spacer()
                    Image(systemName: "multiply.circle.fill")
                        .foregroundColor(.gray)
                        .padding(.trailing, 8)
                        .highPriorityGesture(
                            TapGesture()
                                .onEnded({ self.newname = "" })
                        )
                }
            } else {
                if let status = App.gitTracks[URL(string: item.url)!] {
                    FileDisplayName(
                        gitStatus: status, name: item.name.removingPercentEncoding!)
                } else {
                    FileDisplayName(
                        gitStatus: nil, name: item.name.removingPercentEncoding!)
                }
                Spacer()
            }

        }
        .padding(5)
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("explorer.cell.rename"),
                object: nil
            ),
            perform: { notification in
                print("explorer.cell.rename")
                guard let target = notification.userInfo?["target"] as? String else { return }
                if target == item.id {
                    isRenaming = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        focusedField = .rename
                    }
                }
            }
        )

    }
}
