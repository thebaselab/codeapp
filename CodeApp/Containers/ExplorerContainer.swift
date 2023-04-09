//
//  ExplorerContainer.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI
import UniformTypeIdentifiers

struct ExplorerContainer: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var stateManager: MainStateManager

    @State var selectedURL: String = ""
    @State private var selectKeeper = Set<String>()
    @State private var editMode = EditMode.inactive
    @State private var searchString: String = ""
    @State private var searching: Bool = false

    @AppStorage("explorer.showHiddenFiles") var showHiddenFiles: Bool = false

    func onOpenNewFile() {
        stateManager.showsNewFileSheet.toggle()
    }

    func onPickNewDirectory() {
        stateManager.showsDirectoryPicker.toggle()
    }

    func openSharedFilesApp(urlString: String) {
        let sharedurl = urlString.replacingOccurrences(of: "file://", with: "shareddocuments://")
        if let furl: URL = URL(string: sharedurl) {
            UIApplication.shared.open(furl, options: [:], completionHandler: nil)
        }
    }

    func onDragCell(item: WorkSpaceStorage.FileItemRepresentable) -> NSItemProvider {
        guard let url = item._url else {
            return NSItemProvider()
        }
        if item.subFolderItems != nil {
            let itemProvider = NSItemProvider()
            itemProvider.suggestedName = url.lastPathComponent
            itemProvider.registerFileRepresentation(
                forTypeIdentifier: "public.folder", visibility: .all
            ) {
                $0(url, false, nil)
                return nil
            }
            return itemProvider
        } else {
            guard let provider = NSItemProvider(contentsOf: url) else {
                return NSItemProvider()
            }
            provider.suggestedName = url.lastPathComponent
            return provider
        }
    }

    func onDropToFolder(item: WorkSpaceStorage.FileItemRepresentable, providers: [NSItemProvider])
        -> Bool
    {
        if let provider = providers.first {
            provider.loadItem(forTypeIdentifier: UTType.item.identifier) {
                data, error in
                if let at = data as? URL,
                    let to = item._url?.appendingPathComponent(
                        at.lastPathComponent, conformingTo: .item)
                {
                    App.workSpaceStorage.copyItem(
                        at: at, to: to,
                        completionHandler: { error in
                            if let error = error {
                                App.notificationManager.showErrorMessage(
                                    error.localizedDescription)
                            }
                        })
                }
            }
        }
        return true
    }

    func scrollToActiveEditor(proxy: ScrollViewProxy) {
        if let url = (App.activeEditor as? EditorInstanceWithURL)?.url {
            proxy.scrollTo(url.absoluteString, anchor: .top)
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            InfinityProgressView(enabled: App.workSpaceStorage.explorerIsBusy)

            ScrollViewReader { proxy in
                List {
                    ExplorerEditorListSection(
                        onOpenNewFile: onOpenNewFile,
                        onPickNewDirectory: onPickNewDirectory
                    )
                    ExplorerFileTreeSection(
                        searchString: searchString, onDrag: onDragCell,
                        onDropToFolder: onDropToFolder)
                }
                .listStyle(SidebarListStyle())
                .environment(\.defaultMinListRowHeight, 10)
                .environment(\.editMode, $editMode)
                .onAppear {
                    scrollToActiveEditor(proxy: proxy)
                }
            }

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
                        ).onTapGesture { onOpenNewFile() }
                        Image(systemName: "folder.badge.plus").contentShape(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                        ).hoverEffect(.highlight).font(.subheadline).foregroundColor(
                            Color.init(id: "activityBar.foreground")
                        ).onTapGesture {
                            Task {
                                guard let url = App.workSpaceStorage.currentDirectory._url else {
                                    return
                                }
                                try await App.createFolder(at: url)
                            }
                        }

                        if !App.workSpaceStorage.remoteConnected {
                            Image(systemName: "folder.badge.gear").contentShape(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                            ).hoverEffect(.highlight).font(.subheadline).foregroundColor(
                                Color.init(id: "activityBar.foreground")
                            ).onTapGesture { onPickNewDirectory() }
                        }

                        Image(systemName: "line.3.horizontal.decrease").contentShape(
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
                            for i in selectKeeper {
                                Task {
                                    try await App.duplicateItem(at: URL(string: i)!)
                                }
                            }
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
    }
}
