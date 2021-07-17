//
//  folderCell.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI
import UniformTypeIdentifiers

struct folderCell: View{
    
    @EnvironmentObject var App: MainApp
    @State var item: WorkSpaceStorage.fileItemRepresentable
    @State var showingNewFileSheet = false
    @State var isRenaming = false
    @State var newname = ""
//    @State var showingFileMover = false
    
    init(item: WorkSpaceStorage.fileItemRepresentable){
        self._item = State.init(initialValue: item)
        self._newname = State.init(initialValue: item.name.removingPercentEncoding!)
    }
    
    //    let activityViewController = SwiftUIActivityViewController()
    
    var body: some View{
        Button(action: {
            if item.subFolderItems == nil {
                App.openEditor(urlString: item.url, type: .any)
            }else{
                withAnimation(.easeInOut){
                    if App.workSpaceStorage.expansionStates[item.url] ?? false {
                        App.workSpaceStorage.expansionStates[item.url] = false
                    }else{
                        App.workSpaceStorage.requestDirectoryUpdateAt(id: item.url)
                        App.workSpaceStorage.expansionStates[item.url] = true
                    }
                }
            }
            
        }) {
            ZStack {
                
                if item.url == App.activeEditor?.url && (App.activeEditor?.type == .image || App.activeEditor?.type == .file){
                    Color.init(id: "list.inactiveSelectionBackground").cornerRadius(10.0)
                }else{
                    Color.init(id: "sideBar.background")
                }
                
                HStack {
                    if item.subFolderItems != nil{
                        Image(systemName: "folder")
                            .foregroundColor(.gray)
                            .font(.system(size:14))
                            .frame(width: 14, height: 14)
                    }else{
                        fileIcon(url: newname, iconSize: 14, type: .file)
                            .frame(width: 14, height: 14)
                    }
                    Spacer().frame(width: 10)
                    
                    if isRenaming{
                        HStack{
                            focusableTextField(text: $newname, isRenaming: $isRenaming, isFirstResponder: true, url: URL(string: item.url)!, onFileNameChange: {App.renameFile(url: URL(string: item.url)!, name: newname)})
                            Spacer()
                            Image(systemName: "multiply.circle.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 8)
                                .highPriorityGesture(
                                    TapGesture()
                                        .onEnded({self.newname = ""})
                                )
                        }
                    }else{
                        if let status = App.gitTracks[URL(string: item.url)!.standardizedFileURL]{
                            switch status{
                            case .workTreeModified, .indexModified:
                                Text(item.name.removingPercentEncoding!)
                                    .foregroundColor(Color.init("git.modified"))
                                    .font(.system(size: 14, weight: .light))
                                Spacer()
                                Text("M")
                                    .foregroundColor(Color.init("git.modified"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 5)
                            case .workTreeNew:
                                Text(item.name.removingPercentEncoding!)
                                    .foregroundColor(Color.init("git.untracked"))
                                    .font(.system(size: 14, weight: .light))
                                Spacer()
                                Text("U")
                                    .foregroundColor(Color.init("git.untracked"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 5)
                            case .workTreeDeleted, .indexDeleted:
                                Text(item.name.removingPercentEncoding!)
                                    .foregroundColor(Color.init("git.deleted"))
                                    .font(.system(size: 14, weight: .light))
                                Spacer()
                                Text("D")
                                    .foregroundColor(Color.init("git.deleted"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 5)
                            case .indexNew:
                                Text(item.name.removingPercentEncoding!)
                                    .foregroundColor(Color.init("git.added"))
                                    .font(.system(size: 14, weight: .light))
                                Spacer()
                                Text("A")
                                    .foregroundColor(Color.init("git.added"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 5)
                            default:
                                Text(item.name.removingPercentEncoding!)
                                    .foregroundColor(Color.init(id: "list.inactiveSelectionForeground"))
                                    .font(.system(size: 14, weight: .light))
                                Spacer()
                            }
                        }else{
                            Text(item.name.removingPercentEncoding!)
                                .foregroundColor(Color.init(id: "list.inactiveSelectionForeground"))
                                .font(.system(size: 14, weight: .light))
                            Spacer()
                        }
                    }
                    
                    
                    
                }.padding(5)
            }
        }
        .buttonStyle(NoAnim())
        .sheet(isPresented: $showingNewFileSheet) {
            newFileView(targetUrl: item.url).environmentObject(App)
        }
//        .fileMover(isPresented: $showingFileMover, file: URL(string: item.url), onCompletion: { _ in
//
//        })
        .contextMenu {
            Group{
                
                if item.subFolderItems == nil{
                    Button(action: {
                        App.openEditor(urlString: item.url, type: .any, inNewTab: true)
                    }){
                        Text("Open in Tab")
                        Image(systemName: "doc.plaintext")
                    }
                }
                
                Button(action: {
                    openSharedFilesApp(urlString: URL(string: item.url)!.deletingLastPathComponent().absoluteString)
                }){
                    Text(NSLocalizedString("Show in Files App", comment: ""))
                    Image(systemName: "folder")
                }
                
                Group{
                    Button(action: {
                        isRenaming = true
                        
                    }) {
                        Text(NSLocalizedString("Rename", comment: ""))
                        Image(systemName: "pencil")
                    }
                    
                    Button(action: {
                        App.duplicateItem(from: URL(string: item.url)!)
                    }) {
                        Text("Duplicate")
                        Image(systemName: "plus.square.on.square")
                    }
//
//                    Button(action: {
//                        showingFileMove.toggle()
//                    }) {
//                        Text("Move")
//                        Image(systemName: "doc.on.doc")
//                    }
//
                    Button(action: {
                        App.trashItem(url: URL(string: item.url)!)
                    }) {
                        Text(NSLocalizedString("Delete", comment: "")).foregroundColor(.red)
                        Image(systemName: "trash").foregroundColor(.red)
                    }
                }
                
                
                
            }
            
            Divider()
            
            Button(action: {
                let pasteboard = UIPasteboard.general
                guard let targetURL = URL(string: item.url), let baseURL = URL(string: App.currentURL()) else {
                    return
                }
                pasteboard.string = targetURL.relativePath(from: baseURL)
            }){
                Text(NSLocalizedString("Copy Relative Path", comment: ""))
                Image(systemName: "link")
            }
            
            if item.subFolderItems != nil{
                Button(action: {
                    showingNewFileSheet.toggle()
                }){
                    Text(NSLocalizedString("New File", comment: ""))
                    Image(systemName: "doc.badge.plus")
                }
                
                Button(action: {
                    App.createFolder(urlString: item.url)
                }){
                    Text(NSLocalizedString("New Folder", comment: ""))
                    Image(systemName: "folder.badge.plus")
                }
                
                Button(action: {
                    App.loadFolder(url: URL(string: item.url)!)
                }){
                    Text(NSLocalizedString("Assign as workplace folder", comment: ""))
                    Image(systemName: "folder.badge.gear")
                }
            }
            
            if item.subFolderItems == nil{
                Button(action: {
                    App.selectedForCompare = item.url
                }) {
                    Text(NSLocalizedString("Select for compare", comment: ""))
                    Image(systemName: "square.split.2x1")
                }
                
                if App.selectedForCompare != "" && App.selectedForCompare != item.url{
                    Button(action: {
                        App.compareWithSelected(url: item.url)
                    }) {
                        Text(NSLocalizedString("Compare with selected", comment: ""))
                        Image(systemName: "square.split.2x1")
                    }
                }
            }
        }
//        .onDrag { NSItemProvider(object: URL(string: item.url)! as NSURL) }
        .if(item.subFolderItems != nil && URL(string: item.url) != nil){view in
            view.onDrop(of: [UTType.url], delegate: FilesDropDelegate(destination: URL(string: item.url)!, hoverAction: {App.workSpaceStorage.expansionStates[item.url] = true}))
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
