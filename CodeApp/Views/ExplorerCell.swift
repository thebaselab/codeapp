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
        if item.subFolderItems != nil {
            FolderCell(item: item)
                .frame(height: 16)
                .onDrag(onDrag)
                .onDrop(
                    of: [.folder, .item], isTargeted: nil,
                    perform: onDropToFolder)
        } else {
            FileCell(item: item)
                .frame(height: 16)
                .onDrag(onDrag)
        }
    }
}

private struct FileCell: View {

    @EnvironmentObject var App: MainApp
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

    func onOpenEditor() {
        guard let url = item._url else { return }
        Task {
            do {
                _ = try await App.openFile(url: url)
            } catch {
                App.notificationManager.showErrorMessage(error.localizedDescription)
            }
        }
    }

    func onCopyItemToFolder(url: URL) {
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
    }

    var body: some View {
        Button(action: onOpenEditor) {
            HStack {
                FileIcon(url: newname, iconSize: 14)
                    .frame(width: 14, height: 14)

                if isRenaming {
                    HStack {
                        TextField(item.name.removingPercentEncoding!, text: $newname)
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
                DirectoryPickerView(onOpen: onCopyItemToFolder)
            }
            .contextMenu {
                ContextMenu(
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

        }
    }
}

private struct FolderCell: View {

    @EnvironmentObject var App: MainApp
    @State var item: WorkSpaceStorage.FileItemRepresentable
    @State var showingNewFileSheet = false
    @State var showsDirectoryPicker = false
    @State var newname = ""
    @FocusState var focusedField: Field?
    @State var isRenaming: Bool = false

    enum Field {
        case rename
    }

    init(item: WorkSpaceStorage.FileItemRepresentable) {
        self._item = State.init(initialValue: item)
        self._newname = State.init(initialValue: item.name.removingPercentEncoding!)
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
            Image(systemName: "folder")
                .foregroundColor(.gray)
                .font(.system(size: 14))
                .frame(width: 14, height: 14)
            Spacer().frame(width: 10)

            if isRenaming {
                HStack {
                    TextField(item.name.removingPercentEncoding!, text: $newname)
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
                                    from: textField.beginningOfDocument, to: textField.endOfDocument
                                )
                            }
                        }
                        .onChange(of: focusedField) { field in
                            if field == nil {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    focusedField = .rename
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
        .sheet(isPresented: $showingNewFileSheet) {
            NewFileView(targetUrl: item.url).environmentObject(App)
        }
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
            ContextMenu(
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
                onCopyFile: {
                    showsDirectoryPicker.toggle()
                })
        }
    }
}

private struct ContextMenu: View {

    @EnvironmentObject var App: MainApp

    let item: WorkSpaceStorage.FileItemRepresentable

    let onRename: () -> Void
    let onCreateNewFile: () -> Void
    let onCopyFile: () -> Void

    var body: some View {
        Group {

            if item.subFolderItems == nil {
                Button(action: {
                    if let url = item._url {
                        App.openFile(url: url, alwaysInNewTab: true)
                    }
                }) {
                    Text("Open in Tab")
                    Image(systemName: "doc.plaintext")
                }
            }

            Button(action: {
                openSharedFilesApp(
                    urlString: URL(string: item.url)!.deletingLastPathComponent()
                        .absoluteString
                )
            }) {
                Text("Show in Files App")
                Image(systemName: "folder")
            }

            Group {
                Button(action: {
                    onRename()
                }) {
                    Text("Rename")
                    Image(systemName: "pencil")
                }

                Button(action: {
                    Task {
                        guard let url = item._url else { return }
                        try await App.duplicateItem(at: url)
                    }
                }) {
                    Text("Duplicate")
                    Image(systemName: "plus.square.on.square")
                }

                Button(
                    role: .destructive,
                    action: {
                        App.trashItem(url: URL(string: item.url)!)
                    },
                    label: {
                        Text("Delete")
                        Image(systemName: "trash")
                    })

                Button(action: {
                    onCopyFile()
                }) {
                    Label(
                        item.url.hasPrefix("file") ? "file.copy" : "file.download",
                        systemImage: "folder")
                }
            }

            Divider()

            Button(action: {
                let pasteboard = UIPasteboard.general
                guard let targetURL = URL(string: item.url),
                    let baseURL = (App.activeEditor as? EditorInstanceWithURL)?.url
                else {
                    return
                }
                pasteboard.string = targetURL.relativePath(from: baseURL)
            }) {
                Text("Copy Relative Path")
                Image(systemName: "link")
            }

            if item.subFolderItems != nil {
                Button(action: {
                    onCreateNewFile()
                }) {
                    Text("New File")
                    Image(systemName: "doc.badge.plus")
                }

                Button(action: {
                    Task {
                        guard let url = item._url else { return }
                        try await App.createFolder(at: url)
                    }
                }) {
                    Text("New Folder")
                    Image(systemName: "folder.badge.plus")
                }

                Button(action: {
                    App.loadFolder(url: URL(string: item.url)!)
                }) {
                    Text("Assign as workspace folder")
                    Image(systemName: "folder.badge.gear")
                }
            }

            if item.subFolderItems == nil {
                Button(action: {
                    App.selectedURLForCompare = item._url
                }) {
                    Text("Select for compare")
                    Image(systemName: "square.split.2x1")
                }

                if App.selectedURLForCompare != nil && App.selectedURLForCompare != item._url {
                    Button(action: {
                        guard let url = item._url else { return }
                        Task {
                            do {
                                try await App.compareWithSelected(url: url)
                            } catch {
                                App.notificationManager.showErrorMessage(error.localizedDescription)
                            }

                        }
                    }) {
                        Text("Compare with selected")
                        Image(systemName: "square.split.2x1")
                    }
                }
            }
        }
    }
}
