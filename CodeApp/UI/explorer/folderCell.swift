//
//  folderCell.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI
import UniformTypeIdentifiers

struct FolderCell: View {

    @EnvironmentObject var App: MainApp
    @State var item: WorkSpaceStorage.fileItemRepresentable
    @State var showingNewFileSheet = false
    @State var showsDirectoryPicker = false
    @State var newname = ""
    @FocusState var focusedField: Field?
    @State var isRenaming: Bool = false

    enum Field {
        case rename
    }

    init(item: WorkSpaceStorage.fileItemRepresentable) {
        self._item = State.init(initialValue: item)
        self._newname = State.init(initialValue: item.name.removingPercentEncoding!)
    }

    var body: some View {
        HStack {
            Image(systemName: "folder")
                .foregroundColor(.gray)
                .font(.system(size: 14))
                .frame(width: 14, height: 14)
            Spacer().frame(width: 10)

            if isRenaming {
                HStack {
                    //                    focusableTextField(
                    //                        text: $newname, isRenaming: $isRenaming, isFirstResponder: true,
                    //                        url: URL(string: item.url)!,
                    //                        onFileNameChange: {
                    //                            App.renameFile(url: URL(string: item.url)!, name: newname)
                    //                        })
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
                                from: textField.beginningOfDocument, to: textField.endOfDocument)
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
        .if(item.subFolderItems == nil) { view in
            view.onTapGesture {
                App.openEditor(urlString: item.url, type: .any)
            }
        }
        .listRowBackground(
            item.url == App.activeEditor?.url
                ? Color.init(id: "list.inactiveSelectionBackground").cornerRadius(10.0)
                : Color.clear.cornerRadius(10.0)
        )
        .sheet(isPresented: $showingNewFileSheet) {
            newFileView(targetUrl: item.url).environmentObject(App)
        }
        .sheet(isPresented: $showsDirectoryPicker) {
            DirectoryPickerView(onOpen: { url in
                guard let itemURL = URL(string: item.url) else {
                    return
                }
                App.workSpaceStorage.moveItem(
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
                onCreateNewFile: {
                    showingNewFileSheet.toggle()
                },
                onMoveFile: {
                    showsDirectoryPicker.toggle()
                })
        }
        //        .onDrag { NSItemProvider(object: URL(string: item.url)! as NSURL) }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
        ) { _ in
            isRenaming = false
            newname = item.name.removingPercentEncoding!
        }
    }
}

struct FilesDropDelegate: DropDelegate {

    let destination: URL
    let hoverAction: () -> (Void)

    func performDrop(info: DropInfo) -> Bool {
        guard info.hasItemsConforming(to: [.fileURL]) else {
            return false
        }
        let items = info.itemProviders(for: [.fileURL])

        for item in items {
            _ = item.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    try? FileManager.default.moveItem(at: url, to: destination)
                }
            }
        }
        return true
    }

    func dropEntered(info: DropInfo) {
        hoverAction()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
