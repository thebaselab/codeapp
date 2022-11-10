//
//  explorer.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

struct explorer: View {

    @EnvironmentObject var App: MainApp

    @State var selectedURL: String = ""
    @State private var selectKeeper = Set<String>()
    @State private var editMode = EditMode.inactive
    @Binding var showingNewFileSheet: Bool
    @Binding var showsDirectoryPicker: Bool
    @AppStorage("explorer.showHiddenFiles") var showHiddenFiles: Bool = false
    @State private var searchString: String = ""
    @State private var searching: Bool = false

    func openNewFile() {
        showingNewFileSheet.toggle()
    }

    func openFolder() {
        showsDirectoryPicker = true
    }

    func openSharedFilesApp(urlString: String) {
        let sharedurl = urlString.replacingOccurrences(of: "file://", with: "shareddocuments://")
        if let furl: URL = URL(string: sharedurl) {
            UIApplication.shared.open(furl, options: [:], completionHandler: nil)
        }
    }

    func foldersWithFilter(folder: [WorkSpaceStorage.fileItemRepresentable]?) -> [WorkSpaceStorage
        .fileItemRepresentable]
    {

        var result = [WorkSpaceStorage.fileItemRepresentable]()

        for item in folder ?? [WorkSpaceStorage.fileItemRepresentable]() {
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
            var finalResult = [WorkSpaceStorage.fileItemRepresentable]()
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
        VStack(spacing: 0) {

            InfinityProgressView(enabled: $App.workSpaceStorage.explorerIsBusy)

            List(selection: $selectKeeper) {
                Section(
                    header:
                        Text("Open Editors")
                        .foregroundColor(Color.init("BW"))
                ) {
                    if App.editors.isEmpty {
                        SideBarButton("New File") {
                            openNewFile()
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                        SideBarButton("Open Folder") {
                            openFolder()
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    ForEach(App.editors) { item in
                        cell(item: item)
                            .frame(height: 16)
                            .listRowBackground(
                                item.url == App.activeEditor?.url
                                    ? Color.init(id: "list.inactiveSelectionBackground")
                                        .cornerRadius(10.0)
                                    : Color.clear.cornerRadius(10.0)
                            )
                            .listRowSeparator(.hidden)
                    }
                }

                Section(
                    header:
                        Text(
                            App.workSpaceStorage.currentDirectory.name.replacingOccurrences(
                                of: "{default}", with: " "
                            ).removingPercentEncoding!
                        )
                        .foregroundColor(Color.init("BW"))
                ) {
                    HierarchyList(
                        data: foldersWithFilter(
                            folder: App.workSpaceStorage.currentDirectory.subFolderItems),
                        children: \.subFolderItems,
                        expandStates: $App.workSpaceStorage.expansionStates,
                        rowContent: {
                            FileFolderCell(item: $0)
                                .frame(height: 16)
                                .listRowBackground(
                                    $0.url == App.activeEditor?.url
                                        ? Color.init(id: "list.inactiveSelectionBackground")
                                            .cornerRadius(10.0)
                                        : Color.clear.cornerRadius(10.0)
                                )
                                .listRowSeparator(.hidden)
                        },
                        onDisclose: { id in
                            if let id = id as? String {
                                App.workSpaceStorage.requestDirectoryUpdateAt(id: id)
                            }
                        })
                }
            }.listStyle(SidebarListStyle())
                .environment(\.defaultMinListRowHeight, 10)
                .environment(\.editMode, $editMode)

            Spacer()

            HStack(spacing: 30) {
                if editMode == EditMode.inactive {
                    if searching {
                        HStack {
                            Image(systemName: "line.horizontal.3.decrease").font(.subheadline)
                                .foregroundColor(Color.init(id: "activityBar.foreground"))
                            TextField("Filter", text: $searchString)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            Image(systemName: "checkmark.circle").contentShape(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                            ).hoverEffect(.highlight).font(.subheadline).foregroundColor(
                                Color.init(id: "activityBar.foreground")
                            ).onTapGesture { withAnimation { searching = false } }
                        }
                    } else {
                        Image(systemName: "doc.badge.plus").contentShape(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                        ).hoverEffect(.highlight).font(.subheadline).foregroundColor(
                            Color.init(id: "activityBar.foreground")
                        ).onTapGesture { openNewFile() }
                        Image(systemName: "folder.badge.plus").contentShape(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                        ).hoverEffect(.highlight).font(.subheadline).foregroundColor(
                            Color.init(id: "activityBar.foreground")
                        ).onTapGesture {
                            App.createFolder(urlString: App.workSpaceStorage.currentDirectory.url)
                        }

                        if !App.workSpaceStorage.remoteConnected {
                            Image(systemName: "folder.badge.gear").contentShape(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                            ).hoverEffect(.highlight).font(.subheadline).foregroundColor(
                                Color.init(id: "activityBar.foreground")
                            ).onTapGesture { openFolder() }
                        }

                        Image(systemName: "magnifyingglass").contentShape(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                        ).hoverEffect(.highlight).font(.subheadline).foregroundColor(
                            Color.init(id: "activityBar.foreground")
                        ).onTapGesture { withAnimation { searching = true } }
                        Image(systemName: "arrow.clockwise").contentShape(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                        ).hoverEffect(.highlight).font(.subheadline).foregroundColor(
                            Color.init(id: "activityBar.foreground")
                        ).onTapGesture { App.reloadDirectory() }
                    }
                } else {
                    if selectKeeper.isEmpty {
                        //                        Image(systemName: "square.and.arrow.up").contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous)).hoverEffect(.highlight).font(.subheadline).foregroundColor(.gray)
                        Image(systemName: "trash").contentShape(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                        ).hoverEffect(.highlight).font(.subheadline).foregroundColor(.gray)
                        Image(systemName: "square.on.square").contentShape(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                        ).hoverEffect(.highlight).font(.subheadline).foregroundColor(.gray)
                    } else {
                        //                        Image(systemName: "square.and.arrow.up").contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous)).hoverEffect(.highlight).font(.subheadline).foregroundColor(Color.init(id: "activityBar.foreground"))
                        //                            .onTapGesture{activityViewController.share(urls: Array(selectKeeper).map{URL.init(string: $0)!})}
                        Image(systemName: "trash").contentShape(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                        ).hoverEffect(.highlight).font(.subheadline).foregroundColor(
                            Color.init(id: "activityBar.foreground")
                        ).onTapGesture {
                            for i in selectKeeper {
                                App.trashItem(url: URL(string: i)!)
                                selectKeeper.remove(i)
                            }
                            editMode = EditMode.inactive
                        }
                        Image(systemName: "square.on.square").contentShape(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                        ).hoverEffect(.highlight).font(.subheadline).foregroundColor(
                            Color.init(id: "activityBar.foreground")
                        ).onTapGesture {
                            for i in selectKeeper { App.duplicateItem(from: URL(string: i)!) }
                            editMode = EditMode.inactive
                        }
                    }
                    Image(systemName: "checkmark.circle").contentShape(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                    ).hoverEffect(.highlight).font(.subheadline).foregroundColor(
                        Color.init(id: "activityBar.foreground")
                    ).onTapGesture { withAnimation { editMode = EditMode.inactive } }
                }

            }.padding(.horizontal, 15).padding(.vertical, 8).background(
                Color.init(id: "activityBar.background")
            ).cornerRadius(12).padding(.bottom, 15).padding(.horizontal, 8)

        }
        //        .onDrop(
        //            of: [(kUTTypeText as String), (kUTTypeImage as String)],
        //            delegate: self
        //        )
    }
}
