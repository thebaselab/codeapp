//
//  App.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI
import GCDWebServer
import Combine
import SwiftGit2
import ios_system
import UniformTypeIdentifiers
import CoreSpotlight

class MainApp: ObservableObject {
    @Published var editors: [EditorInstance] = []
    
    @Published var isShowingCompilerLanguage = false
    @Published var activeEditor: EditorInstance? = nil
    @Published var selectedForCompare = ""
    
    @Published var languageEnabled: [Bool] = langListInit()
    @Published var compilerCode: Int = 71
    
    @Published var notificationManager = NotificationManager()
    @Published var compileManager = CloudCodeExecutionManager()
    @Published var searchManager = GitHubSearchManager()
    @Published var textSearchManager = TextSearchManager()
    @Published var workSpaceStorage: WorkSpaceStorage
    
    var gitServiceProvider: GitServiceProvider? = nil
    
    // Editor States
    @Published var problems: [URL:[monacoEditor.Coordinator.marker]] = [:]
    @Published var showsNewFileSheet = false
    @Published var showsDirectoryPicker = false
    
    // Git UI states
    @Published var gitTracks: [URL:Diff.Status] = [:]
    @Published var indexedResources: [URL:Diff.Status] = [:]
    @Published var workingResources: [URL:Diff.Status] = [:]
    @Published var branch: String = ""
    @Published var remote: String = ""
    @Published var commitMessage: String = ""
    @Published var isSyncing: Bool = false
    @Published var aheadBehind: (Int, Int)? = nil
    
    var urlQueue: [URL] = []
    var editorToRestore: URL? = nil
    
    let terminalInstance: TerminalInstance
    let monacoInstance = monacoEditor()
    let webServer = GCDWebServer()
    var editorTypesMonitor: FolderMonitor? = nil
    let readmeMessage = NSLocalizedString("Welcome Message", comment: "")
    
    private var NotificationCancellable: AnyCancellable? = nil
    private var CompilerCancellable: AnyCancellable? = nil
    private var searchCancellable: AnyCancellable? = nil
    private var textSearchCancellable: AnyCancellable? = nil
    private var workSpaceCancellable: AnyCancellable? = nil
    
    @AppStorage("alwaysOpenInNewTab") var alwaysOpenInNewTab: Bool = false
    @AppStorage("compilerShowPath") var compilerShowPath = false
    
    init() {
        
        let rootDir: URL
        
        var stateRestorationEnabled = true
        
        if UserDefaults.standard.object(forKey: "stateRestorationEnabled") != nil {
            stateRestorationEnabled = UserDefaults.standard.bool(forKey: "stateRestorationEnabled")
        }
        
        if UserDefaults.standard.bool(forKey: "uistate.restoredSuccessfully") == false {
            stateRestorationEnabled = false
        }
        
        UserDefaults.standard.setValue(false, forKey: "uistate.restoredSuccessfully")
        
        if stateRestorationEnabled {
            var isStale = false
            if let bookmarkData = UserDefaults.standard.value(forKey: "uistate.root.bookmark") as? Data, let bookmarkedURL = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale){
                rootDir = bookmarkedURL
            }else{
                rootDir = getRootDirectory()
            }
            
            if let bookmarkDatas = UserDefaults.standard.array(forKey: "uistate.openedURLs.bookmarks") as? [Data] {
                for data in bookmarkDatas {
                    var isStale = false
                    let bookmarkedURL = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
                    guard !isStale else {
                        continue
                    }
                    if bookmarkedURL != nil {
                        urlQueue.append(bookmarkedURL!)
                    }
                }
            }
            if let bookmarkData = UserDefaults.standard.value(forKey: "uistate.activeEditor.bookmark") as? Data, let bookmarkedURL = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale){
                editorToRestore = bookmarkedURL
            }
        }else{
            rootDir = getRootDirectory()
        }
        
        self.workSpaceStorage = WorkSpaceStorage(name: rootDir.lastPathComponent, url: rootDir.absoluteString)
        
        terminalInstance = TerminalInstance(root: rootDir)
        gitServiceProvider = GitServiceProvider(root: rootDir)
        
        terminalInstance.openEditor = { url in
            self.openEditor(urlString: url, type: .any)
        }
        workSpaceStorage.onDirectoryChange{ url in
            for editor in self.editors {
                print("editor url is \(editor.url)")
                print("")
                if editor.url.contains(url), let urlToCheck = URL(string: editor.url){
                    if !FileManager.default.fileExists(atPath: urlToCheck.path){
                        editor.isDeleted = true
                    }
                }
            }
        }
        loadRepository(url: rootDir)
        
        NotificationCancellable = notificationManager.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }
        CompilerCancellable = compileManager.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }
        searchCancellable = searchManager.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }
        textSearchCancellable = textSearchManager.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }
        workSpaceCancellable = workSpaceStorage.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }
        
        if urlQueue.isEmpty {
            let newEditor = EditorInstance(url: "welcome.md{welcome}", content: readmeMessage, type: .preview)
            editors.append(newEditor)
            activeEditor = newEditor
        }
        
        let monacoPath = Bundle.main.path(forResource: "monaco-textmate", ofType: "bundle")

        DispatchQueue.main.async {
            monacoWebView.loadFileURL(URL(fileURLWithPath: monacoPath!).appendingPathComponent("index.html"), allowingReadAccessTo: URL(fileURLWithPath: monacoPath!))
        }
        
        webServer.addGETHandler(forBasePath: "/", directoryPath: rootDir.path, indexFilename: "index.html", cacheAge: 10, allowRangeRequests: true)
        
        do{
            try webServer.start(options: [GCDWebServerOption_AutomaticallySuspendInBackground: true, GCDWebServerOption_Port: 8000])
        } catch let error {
            print(error)
        }
    }
    
    func updateView(){
        self.objectWillChange.send()
    }
    
    func saveUserStates(){
        
        // Saving root folder
        if let data = try? URL(string: workSpaceStorage.currentDirectory.url)?.bookmarkData() {
            UserDefaults.standard.setValue(data, forKey: "uistate.root.bookmark")
        }
        
        // Saving opened editors
        let editorsBookmarks = editors.compactMap{try? URL(string: $0.url)?.bookmarkData()}
        UserDefaults.standard.setValue(editorsBookmarks, forKey: "uistate.openedURLs.bookmarks")
        
        // Save active editor
        if editors.isEmpty {
            UserDefaults.standard.setValue(nil, forKey: "uistate.activeEditor.bookmark")
        }else if let data = try? URL(string: activeEditor?.url ?? "")?.bookmarkData() {
            UserDefaults.standard.setValue(data, forKey: "uistate.activeEditor.bookmark")
        }
        
        guard !editors.isEmpty else {
            UserDefaults.standard.setValue(nil, forKey: "uistate.activeEditor.state")
            return
        }
        
        monacoWebView.evaluateJavaScript("JSON.stringify(editor.saveViewState())"){ res, err in
            if let res = res as? String {
                UserDefaults.standard.setValue(res, forKey: "uistate.activeEditor.state")
            }
        }
    }
    
    func createFolder(urlString: String){
        let newurl = urlString + newFileName(defaultName: "New%20Folder", extensionName: "", urlString: urlString)
        guard let url = URL(string: newurl) else{
            return
        }
        do{
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }catch{
            print("Error: \(error.localizedDescription)")
        }
    }
    
    func renameFile(url: URL, name: String){
        var rv = URLResourceValues()
        rv.name = name
        var URL = url
        do{
            try URL.setResourceValues(rv)
        }catch let error{
            notificationManager.showErrorMessage(error.localizedDescription)
            return
        }
        for i in editors.indices{
            if editors[i].url == url.absoluteString{
                editors[i].url = url.deletingLastPathComponent().appendingPathComponent(name).absoluteString
                monacoInstance.renameModel(oldURL: url.absoluteString, newURL: editors[i].url)
                if currentURL() == editors[i].url{
                    monacoInstance.setModel(url: editors[i].url)
                }
            }else if editors[i].url == url.absoluteURL.absoluteString{                editors[i].url = url.deletingLastPathComponent().absoluteURL.appendingPathComponent(name).absoluteString
                monacoInstance.renameModel(oldURL: url.absoluteString, newURL: editors[i].url)
                if currentURL() == editors[i].url{
                    monacoInstance.setModel(url: editors[i].url)
                }
            }
        }
    }
    
    func loadURLQueue(){
        for i in urlQueue{
            openEditor(urlString: i.absoluteString, type: .any, inNewTab: true)
        }
        urlQueue = []
        if editorToRestore != nil {
            openEditor(urlString: editorToRestore!.absoluteString, type: .any)
            editorToRestore = nil
        }
    }
    
    func duplicateItem(from: URL){
        do {
            let newName = newFileName(defaultName: from.deletingPathExtension().lastPathComponent, extensionName: from.pathExtension, urlString: from.deletingLastPathComponent().absoluteString)
            let newURL = from.deletingLastPathComponent().absoluteString + newName
            try FileManager.default.copyItem(at: from, to: URL(string: newURL)!)
            git_status()
        } catch {
            notificationManager.showErrorMessage(error.localizedDescription)
        }
    }
    
    func trashItem(url: URL){
        do {
            try FileManager.default.removeItem(at: url)
            closeEditor(url: url.absoluteString, type: EditorInstance.tabType.file)
            git_status()
        } catch {
            notificationManager.showErrorMessage(error.localizedDescription)
        }
    }
    
    func runCode(url: String, lang: Int){
        saveCurrentFile()
        if lang < 10 {
            switch compilerCode{
            case 0:
                let cmd = "python3 -u \"\(URL(string: activeEditor!.url)!.path.replacingOccurrences(of: " ", with: #"\ "#))\""
                if compilerShowPath {
                    terminalInstance.executeScript("localEcho.println(`\(cmd)`);readLine('');")
                }else{
                    terminalInstance.executeScript("localEcho.println(`python`);readLine('');")
                }
                terminalInstance.executeScript("window.webkit.messageHandlers.toggleMessageHandler2.postMessage({\"Event\": \"Return\", \"Input\": `\(cmd)`})")
            case 1:
                let cmd = "node \(URL(string: activeEditor!.url)!.path.replacingOccurrences(of: " ", with: #"\ "#))"
                if compilerShowPath {
                    terminalInstance.executeScript("localEcho.println(`\(cmd)`);")
                }else{
                    terminalInstance.executeScript("localEcho.println(`node`);")
                }
                terminalInstance.executeScript("window.webkit.messageHandlers.toggleMessageHandler2.postMessage({\"Event\": \"Return\", \"Input\": `\(cmd)`})")
            case 2:
                let cmd = "clang \(URL(string: activeEditor!.url)!.path.replacingOccurrences(of: " ", with: #"\ "#)) && wasm a.out"
                if compilerShowPath {
                    terminalInstance.executeScript("localEcho.println(`\(cmd)`);readLine('');")
                }else{
                    terminalInstance.executeScript("localEcho.println(`clang`);readLine('');")
                }
                terminalInstance.executor?.evaluateCommands(["clang \(URL(string: activeEditor!.url)!.path.replacingOccurrences(of: " ", with: #"\ "#))", "wasm a.out"])
            case 3:
                let cmd = "clang++ \(URL(string: activeEditor!.url)!.path.replacingOccurrences(of: " ", with: #"\ "#)) && wasm a.out"
                if compilerShowPath {
                    terminalInstance.executeScript("localEcho.println(`\(cmd)`);readLine('');")
                }else{
                    terminalInstance.executeScript("localEcho.println(`clang++`);readLine('');")
                }
                terminalInstance.executor?.evaluateCommands(["clang++ \(URL(string: activeEditor!.url)!.path.replacingOccurrences(of: " ", with: #"\ "#))", "wasm a.out"])
            case 4:
                let cmd = "php \"\(URL(string: activeEditor!.url)!.path.replacingOccurrences(of: " ", with: #"\ "#))\""
                if compilerShowPath {
                    terminalInstance.executeScript("localEcho.println(`\(cmd)`);")
                }else{
                    terminalInstance.executeScript("localEcho.println(`php`);")
                }
                terminalInstance.executeScript("window.webkit.messageHandlers.toggleMessageHandler2.postMessage({\"Event\": \"Return\", \"Input\": `\(cmd)`})")
            default:
                return
            }
        }else{
            if let link = URL(string: url){
                compileManager.runCode(directoryURL: link, source: readURL(url: url)!, language: lang)
            }
        }
    }
    
    private func checkOccurancesOfURL(url: String) -> Int{
        var count = 0
        for i in editors{
            if i.url == url{
                count += 1
            }
            if i.compareTo == url{
                count += 1
            }
        }
        return count
    }
    
    func compareWithPrevious(url: URL){
        guard gitTracks[url] != nil else{
            notificationManager.showErrorMessage("No changes are made in this file")
            return
        }
        for i in editors{
            if i.url == url.absoluteString{
                openEditor(urlString: i.url, type: .diff)
                return
            }
        }
        gitServiceProvider?.previous(path: url.absoluteString, error: {
            self.notificationManager.showErrorMessage($0.localizedDescription)
        }){previousText in
            guard let content = self.readURL(url: url.absoluteString) else{
                return
            }
            let newEditor = EditorInstance(url: url.absoluteString, content: content, type: .diff, compareTo: "file://previous/\(url.path)")
            self.editors.append(newEditor)
            self.monacoInstance.switchToDiffView(originalContent: previousText , modifiedContent: content, url: newEditor.compareTo! , url2: url.absoluteString)
            self.activeEditor = newEditor
        }
    }
    
    func compareWithSelected(url: String){
        guard let originalContent = readURL(url: url), let diffContent = readURL(url: selectedForCompare) else {
            return
        }
        let newEditor = EditorInstance(url: url, content: originalContent, type: .diff, compareTo: selectedForCompare)
        editors.append(newEditor)
        activeEditor = newEditor
        monacoInstance.switchToDiffView(originalContent: diffContent, modifiedContent: originalContent, url: selectedForCompare, url2: url)
    }
    
    func reloadCurrentFileWithEncoding(encoding: String.Encoding){
        if let url = URL(string: currentURL()){
            do {
                let data = try Data(contentsOf: url)
                if let string = String(data: data, encoding: encoding){
                    activeEditor?.encoding = encoding
                    activeEditor?.content = string
                    self.monacoInstance.setCurrentModelValue(value: string)
                }else{
                    notificationManager.showErrorMessage("Failed to read file as \(encodingTable[encoding]!)")
                }
            } catch {
                notificationManager.showErrorMessage(error.localizedDescription)
            }
        }
    }
    
    private func readURL(url: String) -> String?{
        do{
            let data = try Data(contentsOf: URL(string: url)!)
            if let string = String(data: data, encoding: .utf8){
                return string
            }
            let encodings: [String.Encoding] = [.windowsCP1252, .gb_18030_2000, .EUC_KR, .ascii]
            for encoding in encodings {
                if let string = String(data: data, encoding: encoding){
                    return string
                }
            }
        }catch{
            print(url)
            print(error.localizedDescription)
        }
        return nil
    }
    
    func saveEditor(editor: EditorInstance){
        if let url = URL(string: editor.url){
            do {
                try editor.content.write(to: url, atomically: true, encoding: editor.encoding)
                DispatchQueue.main.async {
                    editor.lastSavedVersionId = editor.currentVersionId
                    editor.isDeleted = false
                }
                DispatchQueue.global(qos: .utility).async{
                    self.git_status()
                }
            } catch {
                notificationManager.showErrorMessage(error.localizedDescription)
            }
        }
    }
    
    func saveCurrentFile(){
        if editors.isEmpty {return}
        if activeEditor?.type != .file && activeEditor?.type != .diff {return}
        if activeEditor?.lastSavedVersionId == activeEditor?.currentVersionId && !(activeEditor?.isDeleted ?? false) {return}
        
        if let activeEditor = activeEditor, let url = URL(string: activeEditor.url){
            do {
                try activeEditor.content.write(to: url, atomically: true, encoding: activeEditor.encoding)
                activeEditor.lastSavedVersionId = activeEditor.currentVersionId
                activeEditor.isDeleted = false
                git_status()
            } catch {
                notificationManager.showErrorMessage(error.localizedDescription)
            }
        }
        
    }
    
    func addMarkDownPreview(url: URL, content: String){
        if url.pathExtension != "md" && url.pathExtension != "markdown"{
            return
        }
        let newURL = url.absoluteString + "{preview}"
        for i in editors{
            if i.url == newURL{
                openEditor(urlString: i.url, type: .preview)
                return
            }
        }
        editors.append(EditorInstance(url: newURL, content: content, type: .preview))
        openEditor(urlString: newURL, type: .preview)
    }
    
    private func restartWebServer(url: URL){
        webServer.stop()
        webServer.removeAllHandlers()
        webServer.addGETHandler(forBasePath: "/", directoryPath: url.path, indexFilename: "index.html", cacheAge: 10, allowRangeRequests: true)
        print(url.absoluteString)
        do{
            try webServer.start(options: [GCDWebServerOption_AutomaticallySuspendInBackground: true, GCDWebServerOption_Port: 8000])
        } catch let error {
            print(error)
        }
    }
    
    func currentURL() -> String{
        return activeEditor?.url ?? ""
    }
    
    func reloadDirectory(){
        guard let url = URL(string: workSpaceStorage.currentDirectory.url) else {
            return
        }
        loadFolder(url: url, resetEditors: false)
    }
    
    func git_status(){
        gitServiceProvider?.status(error: {_ in
            
            DispatchQueue.main.async{
                self.remote = ""
                self.branch = ""
                self.gitTracks = [:]
                self.indexedResources = [:]
                self.workingResources = [:]
            }
        }){ indexed, worktree, branch in
            guard let hasRemote = self.gitServiceProvider?.hasRemote() else {
                return
            }
            DispatchQueue.main.async {
                if hasRemote{
                    self.remote = "origin"
                }else{
                    self.remote = ""
                }
                self.branch = branch
                print("Indexed resource count: \(indexed.count)")
                print("Indexed resource count: \(worktree.count)")
                self.indexedResources = indexed
                self.workingResources = worktree
                print(self.indexedResources.keys)
                print(self.workingResources.keys)
                self.gitTracks = indexed
                worktree.forEach {key, value in
                    self.gitTracks[key] = value
                }
            }
            
            self.gitServiceProvider?.aheadBehind(error: {
                print($0.localizedDescription)
                DispatchQueue.main.async {
                    self.aheadBehind = nil
                }
            }){ result in
                DispatchQueue.main.async {
                    self.aheadBehind = result
                }
            }
        }
    }
    
    func loadRepository(url: URL){
        gitServiceProvider = GitServiceProvider(root: url.standardizedFileURL)
        git_status()
    }
    
    // Injecting JavaScript / TypeScript types
    func scanForTypes(){
        guard let typesURL = URL(string: workSpaceStorage.currentDirectory.url)?.appendingPathComponent("node_modules") else {
            return
        }
        self.monacoInstance.injectTypes(url: typesURL)
        editorTypesMonitor = FolderMonitor(url: typesURL)
        
        if FileManager.default.fileExists(atPath: typesURL.path) {
            editorTypesMonitor?.startMonitoring()
            editorTypesMonitor?.folderDidChange = {
                self.monacoInstance.injectTypes(url: typesURL)
            }
        }
    }
    
    func loadFolder(url: URL, resetEditors: Bool = true){
        ios_setDirectoryURL(url)
        scanForTypes()
        
        DispatchQueue.main.async {
            self.workSpaceStorage.updateDirectory(name: url.lastPathComponent, url: url.absoluteString)
        }
        
        restartWebServer(url: url)
        
        loadRepository(url: url)
        
        if let data = try? url.bookmarkData(){
            if var datas = UserDefaults.standard.value(forKey: "recentFolder") as? [Data]{
                var existingName:[String] = []
                for data in datas{
                    var isStale = false
                    if let newURL = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale){
                        existingName.append(newURL.lastPathComponent)
                    }
                }
                if let index = existingName.firstIndex(of: url.lastPathComponent){
                    datas.remove(at: index)
                }
                datas = [data] + datas
                if datas.count > 5{
                    datas.removeLast()
                }
                UserDefaults.standard.setValue(datas, forKey: "recentFolder")
                
            }else{
                UserDefaults.standard.setValue([data], forKey: "recentFolder")
            }
        }
        if resetEditors{
            DispatchQueue.main.async {
                self.closeAllEditors()
                self.terminalInstance.resetAndSetNewRootDirectory(url: url)
            }
        }
    }
    
    func closeAllEditors(){
        if editors.isEmpty {
            return
        }
        monacoInstance.removeAllModel()
        if activeEditor?.type == .diff{
            monacoInstance.switchToNormView()
        }
        editors.removeAll(keepingCapacity: false)
        activeEditor = nil
    }
    
    func updateCompilerCode(pathExtension: String) {
        var found = false
        
        if (languageEnabled[0] && pathExtension == "py"){
            found = true
            compilerCode = 0
            isShowingCompilerLanguage = true
        }else if (languageEnabled[1] && pathExtension == "js"){
            found = true
            compilerCode = 1
            isShowingCompilerLanguage = true
        }else{
            for i in languageList.sorted(by: {$0.key < $1.key}){
                if i.value[1] == pathExtension && languageEnabled[i.key]{
                    compilerCode = i.key
                    isShowingCompilerLanguage = true
                    found = true
                    break
                }
            }
        }
        
        
        if !found {
            isShowingCompilerLanguage = false
        }
    }
    
    func openEditor(urlString: String, type: EditorInstance.tabType, inNewTab: Bool = false) {
        
        if let pathextension = urlString.split(separator: ".").last{
            updateCompilerCode(pathExtension: String(pathextension))
        }
        
        for editor in editors {
            if type == .any && editor.type == .diff{
                continue
            }
            if(editor.url == urlString && (editor.type == type || type == .any) ){
                if(activeEditor != editor){
                    if editor.type == .file && activeEditor?.type == .diff{
                        monacoInstance.switchToNormView()
                    }
                    if editor.type == .diff && activeEditor?.type == .file{
                        monacoInstance.switchToDiffView(originalContent: "", modifiedContent: editor.content, url: editor.compareTo! , url2: editor.url)
                    }
                    if editor.type == .file{
                        monacoInstance.setModel(from: currentURL(), url: urlString)
                    }
                    activeEditor = editor
                }
                return
            }
        }
        
        guard let url = URL(string: urlString) else{
            if urlString == "welcome.md{welcome}" {
                let newEditor = EditorInstance(url: "welcome.md{welcome}", content: readmeMessage, type: .preview)
                editors.append(newEditor)
                activeEditor = newEditor
            }
            return
        }
        
        UIApplication.shared.openSessions.first?.scene?.title = url.lastPathComponent
        
        if url.pathExtension == "icloud" {
            let fileManager = FileManager.default
            do {
                try fileManager.startDownloadingUbiquitousItem(at: url )
                self.notificationManager.showInformationMessage("Downloading \(url.lastPathComponent)")
            } catch {
                self.notificationManager.showErrorMessage("Download failed: \(error.localizedDescription)")
            }
            return
        }
        
        guard let typeID = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier, let supertypes = UTType(typeID)?.supertypes else {
            return
        }
        
        if supertypes.contains(.mpeg4Movie) || supertypes.contains(.movie){
            let newEditor = EditorInstance(url: url.absoluteString, content: "Video", type: .video)
            editors.append(newEditor)
            activeEditor = newEditor
            return
        }
        
//        guard supertypes.contains(.data) || supertypes.contains(.text) || supertypes.contains(.plainText) || supertypes.contains(.sourceCode) else {
//            notificationManager.showErrorMessage("Unsupported file: \(supertypes)")
//            return
//        }
        
        let data: Data
        
        do{
            data = try Data(contentsOf: url)
        }catch{
            notificationManager.showErrorMessage(error.localizedDescription)
            print(url)
            print(error)
            return
        }
        
        func newTab(editor: EditorInstance){
            if let activeEditor = activeEditor, !alwaysOpenInNewTab && !inNewTab{
                if activeEditor.currentVersionId == 1{
                    for i in editors.indices {
                        if editors[i] == activeEditor {
                            editors[i] = editor
                            break
                        }
                    }
                    self.activeEditor = editor
                    return
                }
            }
            editors.append(editor)
            activeEditor = editor
        }
        
        func newEditor(content: String, encoding: String.Encoding){

            // Add a new editor
            let newEditor = EditorInstance(url: url.absoluteString, content: content, type: .file, encoding: encoding){ state, content in
                if state == .modified {
                    DispatchQueue.main.async {
                        self.monacoInstance.updateModelContent(url: url.absoluteString, content: content!)
                    }
                }
            }
            
            if activeEditor?.type == .diff{
                monacoInstance.switchToNormView()
            }
            if let activeEditor = activeEditor, !alwaysOpenInNewTab && !inNewTab{
                if activeEditor.currentVersionId == 1{
                    let oldurl = activeEditor.url
                    for i in editors.indices {
                        if editors[i] == activeEditor {
                            editors[i] = newEditor
                            break
                        }
                    }
                    self.activeEditor = newEditor
                    monacoInstance.newModel(url: url.absoluteString, content: content)
                    monacoInstance.removeModel(url: oldurl)
                    return
                }
            }
            editors.append(newEditor)
            activeEditor = newEditor
            monacoInstance.newModel(url: url.absoluteString, content: content)
        }
        
        if let string = String(data: data, encoding: .utf8) {
            newEditor(content: string, encoding: .utf8)
        }else if let string = String(data: data, encoding: .gb_18030_2000){
            newEditor(content: string, encoding: .gb_18030_2000)
        }else if let string = String(data: data, encoding: .EUC_KR){
            newEditor(content: string, encoding: .EUC_KR)
        }else if let image = UIImage(data: data){
            let newEditor = EditorInstance(url: url.absoluteString, content: "Image", type: .image, image: Image(uiImage: image))
            newTab(editor: newEditor)
        }else{
            notificationManager.showErrorMessage("Unsupported file")
        }
    }
    
    func closeEditor(url: String, type: EditorInstance.tabType){
        var index = -1
        for y in 0..<editors.count{
            if(editors[y].url == url && editors[y].type == type){
                index = y
            }
        }
        if index == -1 {
            return
        }
        
        if(index-1 >= 0){
            if editors[index].type == .diff && editors[index-1].type != .diff{
                if checkOccurancesOfURL(url: url) == 1 {
                    monacoInstance.removeModel(url: url)
                }
                if checkOccurancesOfURL(url: editors[index].compareTo!) == 1 {
                    monacoInstance.removeModel(url: editors[index].compareTo!)
                }
                monacoInstance.switchToNormView()
            }
            openEditor(urlString: editors[index-1].url, type: editors[index-1].type)
            if checkOccurancesOfURL(url: url) == 1 {
                monacoInstance.removeModel(url: url)
            }
            editors.remove(at: index)
        }else if editors.count > 1{
            if editors[index].type == .diff && editors[index+1].type != .diff{
                if checkOccurancesOfURL(url: url) == 1 {
                    monacoInstance.removeModel(url: url)
                }
                if checkOccurancesOfURL(url: editors[index].compareTo!) == 1 {
                    monacoInstance.removeModel(url: editors[index].compareTo!)
                }
                monacoInstance.switchToNormView()
            }
            openEditor(urlString: editors[index+1].url, type: editors[index+1].type)
            if checkOccurancesOfURL(url: url) == 1 {
                monacoInstance.removeModel(url: url)
            }
            activeEditor = editors[index+1]
            editors.remove(at: index)
        }else{
            monacoInstance.removeModel(url: url)
            activeEditor = nil
            editors = []
            monacoInstance.switchToNormView()
        }
    }
    
}
