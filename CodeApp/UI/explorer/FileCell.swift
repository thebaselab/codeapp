//
//  FileCell.swift
//  Code
//
//  Created by Ken Chung on 24/4/2022.
//

import SwiftUI

struct FileCell: View {

    @EnvironmentObject var App: MainApp
    @State var item: WorkSpaceStorage.fileItemRepresentable
    @State var newname = ""
    @State var showsDirectoryPicker = false
    @FocusState var focusedField: Field?
    @State var isRenaming: Bool = false

    init(item: WorkSpaceStorage.fileItemRepresentable) {
        self._item = State.init(initialValue: item)
        self._newname = State.init(initialValue: item.name.removingPercentEncoding!)
    }

    enum Field {
        case rename
    }
    var body: some View {
        Button(action: {
            App.openEditor(urlString: item.url, type: .any)
        }) {
            HStack {
                fileIcon(url: newname, iconSize: 14, type: .file)
                    .frame(width: 14, height: 14)

                if isRenaming {
                    HStack {
                        TextField(
                            item.name.removingPercentEncoding!, text: $newname,
                            onCommit: {
                                App.renameFile(url: URL(string: item.url)!, name: newname)
                                focusedField = nil
                            }
                        )
                        .focused($focusedField, equals: .rename)
                        .font(.subheadline)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .onReceive(
                            NotificationCenter.default.publisher(
                                for: UITextField.textDidBeginEditingNotification)
                        ) { obj in
                            if let textField = obj.object as? UITextField {
                                textField.selectedTextRange = textField.textRange(
                                    from: textField.beginningOfDocument, to: textField.endOfDocument
                                )
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
                    if let status = App.gitTracks[URL(string: item.url)!.standardizedFileURL] {
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
            .sheet(isPresented: $showsDirectoryPicker) {
                DirectoryPickerView(onOpen: { url in
                    guard let itemURL = URL(string: item.url) else {
                        return
                    }
                    App.workSpaceStorage.copyItem(
                        at: itemURL, to: url.appendingPathComponent(itemURL.lastPathComponent),
                        completionHandler: { error in
                            if let error = error {
                                App.notificationManager.showErrorMessage(error.localizedDescription)
                            }
                        })
                })
            }
            .contextMenu {
                FileCellContextMenu(
                    item: item,
                    onRename: {
                        isRenaming = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            focusedField = .rename
                        }
                    },
                    onCreateNewFile: {},
                    onCopyFile: { showsDirectoryPicker.toggle() }
                )
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            ) { _ in
                isRenaming = false
                newname = item.name.removingPercentEncoding!
            }
        }
    }
}
