//
//  bottomBar.swift
//  Code
//
//  Created by Ken Chung on 1/7/2021.
//

import SwiftUI

struct bottomBar: View {
    
    @EnvironmentObject var App: MainApp
    
    @State var isShowingCheckoutAlert: Bool = false
    @State var selectedBranch: GitServiceProvider.checkoutDest? = nil
    @State var checkoutDetached: Bool = false
    @State var showChangeLog: Bool
    @Binding var showingNewFileSheet: Bool
    @Binding var showSafari: Bool
    @Binding var showsFilePicker: Bool
    @Binding var showsDirectoryPicker: Bool
    @AppStorage("editorReadOnly") var editorReadOnly = false
    @AppStorage("editorFontSize") var editorTextSize: Int = 14
    
    let openConsolePanel: () -> Void
    let onDirectoryPickerFinished: () -> Void
    // Somehow it doesn't compile with arguments in the function
    func checkout(){
        switch selectedBranch?.type{
        case .tag:
            App.gitServiceProvider?.checkout(tagName: selectedBranch!.name, detached: checkoutDetached, error: {
                App.notificationManager.showErrorMessage($0.localizedDescription)
            }){
                App.notificationManager.showInformationMessage("Checkout succeeded")
                App.git_status()
            }
            
        case .local_branch:
            App.gitServiceProvider?.checkout(localBranchName: selectedBranch!.name, detached: checkoutDetached, error: {
                App.notificationManager.showErrorMessage($0.localizedDescription)
            }){
                App.notificationManager.showInformationMessage("Checkout succeeded")
                App.git_status()
            }
        case .remote_branch:
            App.gitServiceProvider?.checkout(remoteBranchName: selectedBranch!.name, detached: checkoutDetached, error: {
                App.notificationManager.showErrorMessage($0.localizedDescription)
            }){
                App.notificationManager.showInformationMessage("Checkout succeeded")
                App.git_status()
            }
        case .none:
            break
        }
    }
    var body: some View {
        ZStack(alignment: .center){
            Color.init(id: "statusBar.background").frame(maxHeight: 20)
            HStack(){
                
                
                HStack{
                    if (App.branch) != "" {
                        
                        HStack{
                            Image(systemName: "arrow.triangle.branch").font(.system(size: 10)).foregroundColor(Color.init(id: "statusBar.foreground"))
                            Text("\(App.branch)").font(.system(size: 12)).foregroundColor(Color.init(id: "statusBar.foreground"))
                        }.contextMenu{
                            if let destinations = App.gitServiceProvider?.checkoutDestinations(){
                                Section{
                                    Menu{
                                        ForEach(destinations){value in
                                            Button(action:{
                                                selectedBranch = value
                                                checkoutDetached = true
                                                if !App.gitTracks.isEmpty{
                                                    isShowingCheckoutAlert = true
                                                }else{
                                                    checkout()
                                                }
                                            }){
                                                Text("\(value.name) at \(value.oid)")
                                                if value.type == .tag {
                                                    Image(systemName: "tag")
                                                }else{
                                                    Image(systemName: "arrow.triangle.branch")
                                                }
                                            }
                                        }
                                    } label: {
                                        Label("Checkout detached...", systemImage: "bolt.horizontal")
                                    }
                                }
                                
                                ForEach(destinations){value in
                                    Button(action:{
                                        selectedBranch = value
                                        checkoutDetached = false
                                        if !App.gitTracks.isEmpty{
                                            isShowingCheckoutAlert = true
                                        }else{
                                            checkout()
                                        }
                                        
                                    }){
                                        Text("\(value.name) at \(value.oid)")
                                        if value.type == .tag {
                                            Image(systemName: "tag")
                                        }else{
                                            Image(systemName: "arrow.triangle.branch")
                                        }
                                    }
                                }
                                
                                
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(height: 20)
                        .alert(isPresented:$isShowingCheckoutAlert) {
                            Alert(title: Text("Git checkout: Uncommitted Changes"), message: Text("Uncommited changes will be lost. Do you wish to proceed?"), primaryButton: .destructive(Text("Checkout")) {
                                checkout()
                            }, secondaryButton: .cancel())
                        }
                        
                        if App.remote != ""{
                            
                            if App.aheadBehind != nil {
                                Text("\(App.aheadBehind!.1)↓ \(App.aheadBehind!.0)↑").font(.system(size: 12)).foregroundColor(Color.init(id: "statusBar.foreground"))
                            }
                            
                            // Git Sync is yet to be implemented in SwiftGit
                            
//                                        Button(action: {isShowingSyncAlert = true}){
//                                            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 10)).foregroundColor(.white)
//                                        }
//                                        .rotationEffect(Angle.degrees(App.isSyncing ? 360 : 0))
//                                        .animation(App.isSyncing ? Animation.linear(duration: 2.0).repeatForever(autoreverses: false) : .default)
//                                        .alert(isPresented:$isShowingSyncAlert) {
//                                            Alert(title: Text("Synchronize Changes"), message: Text("This will pull remote changes down to your local repository and then push local commits to the upstream branch. Conflicts will be merged and overriden by the local copy."), primaryButton: .default(Text("Sync")) {
//                                                App.syncRepository()
//                                            }, secondaryButton: .cancel())
//                                        }
                            
                        }
//                                    if App.remote == ""{
//                                        Button(action: {App.syncRepository()}){
//                                            Image(systemName: "icloud.and.arrow.up").font(.system(size: 12)).foregroundColor(.white)
//                                        }
//                                    }else{
//                                        Button(action: {App.syncRepository()}){
//                                            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 12)).foregroundColor(.white)
//                                        }
//                                    }
                    }
                    if App.isShowingCompilerLanguage{
                        Text("\(languageList[App.compilerCode]?[0] ?? "")").font(.system(size: 12)).foregroundColor(Color.init(id: "statusBar.foreground"))
                    }
                    if let activeEditor = App.activeEditor, activeEditor.type == .image, let imageURL = URL(string: activeEditor.url), let uiImage = UIImage(contentsOfFile: imageURL.path) {
                        Text("\(activeEditor.url.components(separatedBy: ".").last?.uppercased() ?? "") \(String(describing: Int(uiImage.size.width * uiImage.scale)))x\(String(describing: Int(uiImage.size.height * uiImage.scale)))").font(.system(size: 12)).foregroundColor(Color.init(id: "statusBar.foreground"))
                    }
                }.padding(.leading, [UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0, 5].max())
                
                Spacer()
                
                HStack{
                    Group{
                        Button("New File"){
                            showingNewFileSheet.toggle()
                        }.keyboardShortcut("n", modifiers: [.command])
                        
                        Button("Open File"){
                            showsFilePicker.toggle()
                        }.keyboardShortcut("o", modifiers: [.command])
                        .sheet(isPresented: self.$showsFilePicker) {
                            DocumentPickerView()
                        }
                        Button("Save"){
                            App.saveCurrentFile()
                            
                        }.keyboardShortcut("s", modifiers: [.command])
                        .sheet(isPresented: $showChangeLog, content: {
                            changeLogWrapper()
                        })
                        if #available(iOS 15, *) {
                            Button("Select All"){
                                App.monacoInstance.executeJavascript(command: "if(document.activeElement.className.includes('monaco')){editor.setSelection(editor.getModel().getFullModelRange())};")
                            }.keyboardShortcut("a", modifiers: [.command])
                        }
                        Button("Close Editor"){App.closeEditor(url: App.currentURL(), type: App.activeEditor?.type ?? .any)}
                            .keyboardShortcut("w", modifiers: [.command])
                            .sheet(isPresented: self.$showsDirectoryPicker) {
                                DirectoryPickerView(onOpen: {
                                    onDirectoryPickerFinished()
                                })
                            }
                        Button("Command Palatte"){
                            App.monacoInstance.executeJavascript(command: "editor.trigger('', 'editor.action.quickCommand')")
                        }
                        .keyboardShortcut("p", modifiers: [.command, .shift])
                        .fullScreenCover(isPresented: self.$showSafari) {
                            if let currentEditor = App.activeEditor?.url,
                               let baseURL = URL(string: App.workSpaceStorage.currentDirectory.url),
                               let relativePath = URL(string: currentEditor)?.relativePath(from: baseURL)?.replacingOccurrences(of: " ", with: "%20"),
                               let urlToGo = URL(string: "http://localhost:8000/\(relativePath)") {
                                SafariView(url: urlToGo)
                            }else{
                                SafariView(url: URL(string: "http://localhost:8000/")!)
                            }
                        }
                    }

                    Group{
                        Button("Show Panel"){
                            openConsolePanel()
                        }.keyboardShortcut("j", modifiers: .command)
                        Button("Zoom in"){
                            if self.editorTextSize < 30{
                                self.editorTextSize += 1
                                App.monacoInstance.executeJavascript(command: "editor.updateOptions({fontSize: \(String(self.editorTextSize))})")
                            }
                        }.keyboardShortcut("+", modifiers: [.command])
                        Button(action: {
                            if self.editorTextSize < 30{
                                self.editorTextSize += 1
                                App.monacoInstance.executeJavascript(command: "editor.updateOptions({fontSize: \(String(self.editorTextSize))})")
                            }
                        }){
                            Image(systemName: "plus")
                        }.keyboardShortcut("=", modifiers: [.command])

                        Button("Zoom out"){
                            if self.editorTextSize > 10{
                                self.editorTextSize -= 1
                                App.monacoInstance.executeJavascript(command: "editor.updateOptions({fontSize: \(String(self.editorTextSize))})")
                            }
                        }.keyboardShortcut("-", modifiers: [.command])
                    }

                }.foregroundColor(.clear).font(.system(size: 1))
                
                Spacer()
                HStack{
                    
                    if App.activeEditor?.type == .file || App.activeEditor?.type == .diff{
                                                            
                        Text("Ln \(String(App.currentLine)), Col \(String(App.currentColumn))")
                            .font(.system(size: 12))
                            .foregroundColor(Color.init(id: "statusBar.foreground"))
                            .onTapGesture{
                                App.monacoInstance.executeJavascript(command: "editor.focus();editor.trigger('', 'editor.action.gotoLine')")
                            }
                        
                        if editorReadOnly {
                            Text("READ-ONLY").font(.system(size: 12)).foregroundColor(Color.init(id: "statusBar.foreground"))
                        }
                        
                        if let editor = App.activeEditor {
                            Text("\((encodingTable[editor.encoding]) ?? editor.encoding.description)").font(.system(size: 12)).foregroundColor(Color.init(id: "statusBar.foreground"))
                                .contextMenu{
                                    ForEach(Array(encodingTable.keys), id: \.self){value in
                                        Button(action:{App.reloadCurrentFileWithEncoding(encoding: value)}){
                                            Text(encodingTable[value] ?? value.description)
                                            Image(systemName: "textformat")
                                        }
                                    }
                                }
                        }
                    }
                }.foregroundColor(Color.init(id: "statusBar.foreground")).frame(maxHeight: 20).padding(.trailing, [UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0, 5].max())
                
                
            }
        }
    }
}
