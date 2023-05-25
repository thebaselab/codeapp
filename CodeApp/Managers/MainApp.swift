//
//  App.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import Combine
import CoreSpotlight
import SwiftGit2
import SwiftUI
import UniformTypeIdentifiers
import ios_system

class SafariManager: ObservableObject {
    @Published var showsSafari: Bool = false

    var urlToVisit: URL?

    func showSafari(url: URL) {
        self.urlToVisit = url
        showsSafari = true
    }
}

class AlertManager: ObservableObject {
    @Published var isShowingAlert = false

    var title: LocalizedStringKey = ""
    var alertContent: AnyView = AnyView(EmptyView())

    func showAlert(title: LocalizedStringKey, content: AnyView) {
        self.title = title
        self.alertContent = content
        isShowingAlert = true
    }
}

class MainStateManager: ObservableObject {
    @Published var showsNewFileSheet = false
    @Published var showsDirectoryPicker = false
    @Published var showsFilePicker = false
    @Published var showsChangeLog: Bool = false
    @Published var showsSettingsSheet: Bool = false
    @Published var showsCheckoutAlert: Bool = false
    @Published var selectedBranch: checkoutDest? = nil
    @Published var checkoutDetached: Bool = false
    @Published var gitServiceIsBusy = false
    @Published var isMonacoEditorInitialized = false
}

class MainApp: ObservableObject {
    let extensionManager = ExtensionManager()
    let stateManager = MainStateManager()
    let alertManager = AlertManager()
    let safariManager = SafariManager()

    @Published var editors: [EditorInstance] = []
    var textEditors: [TextEditorInstance] {
        editors.filter { $0 is TextEditorInstance } as? [TextEditorInstance] ?? []
    }
    var editorsWithURL: [EditorInstanceWithURL] {
        editors.filter { $0 is EditorInstanceWithURL } as? [EditorInstanceWithURL] ?? []
    }

    @Published var isShowingCompilerLanguage = false
    @Published var activeEditor: EditorInstance? = nil
    var activeTextEditor: TextEditorInstance? {
        activeEditor as? TextEditorInstance
    }

    @Published var selectedURLForCompare: URL? = nil
    @Published var notificationManager = NotificationManager()
    @Published var searchManager = GitHubSearchManager()
    @Published var textSearchManager = TextSearchManager()
    @Published var workSpaceStorage: WorkSpaceStorage

    // Editor States
    @Published var problems: [URL: [MonacoEditor.Coordinator.marker]] = [:]

    // Git UI states
    @Published var gitTracks: [URL: Diff.Status] = [:]
    @Published var indexedResources: [URL: Diff.Status] = [:]
    @Published var workingResources: [URL: Diff.Status] = [:]
    @Published var branch: String = ""
    @Published var remote: String = ""
    @Published var commitMessage: String = ""
    @Published var isSyncing: Bool = false
    @Published var aheadBehind: (Int, Int)? = nil

    var urlQueue: [URL] = []
    var editorShortcuts: [MonacoEditor.Coordinator.action] = []

    let terminalInstance: TerminalInstance
    let monacoInstance = MonacoEditor()
    var editorTypesMonitor: FolderMonitor? = nil
    let deviceSupportsBiometricAuth: Bool = biometricAuthSupported()
    let sceneIdentifier = UUID()

    private var NotificationCancellable: AnyCancellable? = nil
    private var CompilerCancellable: AnyCancellable? = nil
    private var searchCancellable: AnyCancellable? = nil
    private var textSearchCancellable: AnyCancellable? = nil
    private var workSpaceCancellable: AnyCancellable? = nil

    @AppStorage("alwaysOpenInNewTab") var alwaysOpenInNewTab: Bool = false
    @AppStorage("compilerShowPath") var compilerShowPath = false
    @AppStorage("editorSpellCheckEnabled") var editorSpellCheckEnabled = false
    @AppStorage("editorSpellCheckOnContentChanged") var editorSpellCheckOnContentChanged = true

    init() {

        let rootDir: URL = getRootDirectory()

        self.workSpaceStorage = WorkSpaceStorage(url: rootDir)

        terminalInstance = TerminalInstance(root: rootDir)

        terminalInstance.openEditor = { [weak self] url in
            if url.isDirectory {
                DispatchQueue.main.async {
                    self?.loadFolder(url: url)
                }
            } else {
                self?.openFile(url: url)
            }
        }

        // TODO: Support deleted files detection for remote files
        workSpaceStorage.onDirectoryChange { [weak self] url in
            DispatchQueue.main.async {
                for editor in self?.textEditors ?? [] {
                    if editor.url.absoluteString.contains(url) {
                        if !FileManager.default.fileExists(atPath: editor.url.path) {
                            editor.isDeleted = true
                        }
                    }
                }
                self?.git_status()
            }
        }
        workSpaceStorage.onTerminalData { [weak self] data in
            self?.terminalInstance.write(data: data)
        }
        loadRepository(url: rootDir)

        NotificationCancellable = notificationManager.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }
        searchCancellable = searchManager.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }
        textSearchCancellable = textSearchManager.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }
        workSpaceCancellable = workSpaceStorage.objectWillChange.sink { [weak self] (_) in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }

        if urlQueue.isEmpty {
            DispatchQueue.main.async {
                self.showWelcomeMessage()
            }
        }

        let monacoPath = Bundle.main.path(forResource: "monaco-textmate", ofType: "bundle")

        DispatchQueue.main.async {
            self.monacoInstance.monacoWebView.loadFileURL(
                URL(fileURLWithPath: monacoPath!).appendingPathComponent("index.html"),
                allowingReadAccessTo: URL(fileURLWithPath: monacoPath!))
        }

        git_status()
    }

    @MainActor
    func showWelcomeMessage() {
        let instnace = EditorInstance(
            view: AnyView(
                WelcomeView(
                    onCreateNewFile: {
                        self.stateManager.showsNewFileSheet.toggle()
                    },
                    onSelectFolderAsWorkspaceStorage: { url in
                        self.loadFolder(url: url, resetEditors: true)
                    },
                    onSelectFolder: {
                        self.stateManager.showsDirectoryPicker.toggle()
                    },
                    onSelectFile: {
                        self.stateManager.showsFilePicker.toggle()
                    },
                    onNavigateToCloneSection: {
                        // TODO: Modify SceneStorage?
                    }
                )

            ), title: NSLocalizedString("Welcome", comment: ""))

        appendAndFocusNewEditor(editor: instnace, alwaysInNewTab: true)
    }

    func updateView() {
        self.objectWillChange.send()
    }

    func saveUserStates() {

        // Saving root folder
        if let currentDir = URL(string: workSpaceStorage.currentDirectory.url),
            currentDir.scheme == "file",
            let data = try? currentDir.bookmarkData()
        {
            UserDefaults.standard.setValue(data, forKey: "uistate.root.bookmark")
        } else {
            // If the current directory is a remote directory, or cannot be saved as a bookmark,
            // we don't save the state.
            return
        }

        // TODO: Also save non text files
        // Saving opened editors
        let editorsBookmarks = textEditors.compactMap { try? $0.url.bookmarkData() }
        UserDefaults.standard.setValue(editorsBookmarks, forKey: "uistate.openedURLs.bookmarks")

        // Save active editor
        if editors.isEmpty {
            UserDefaults.standard.setValue(nil, forKey: "uistate.activeEditor.bookmark")
        } else if let activeEditor = activeEditor as? TextEditorInstance,
            let data = try? activeEditor.url.bookmarkData()
        {
            UserDefaults.standard.setValue(data, forKey: "uistate.activeEditor.bookmark")
        }

        guard !editors.isEmpty else {
            UserDefaults.standard.setValue(nil, forKey: "uistate.activeEditor.state")
            return
        }

        monacoInstance.monacoWebView.evaluateJavaScript("JSON.stringify(editor.saveViewState())") {
            res, err in
            if let res = res as? String {
                UserDefaults.standard.setValue(res, forKey: "uistate.activeEditor.state")
            }
        }
    }

    func createFolder(at: URL, named: String = "New Folder") async throws {
        let folderURL = at.appendingPathComponent(named)
        let url = try await workSpaceStorage.urlWithSuffixIfExistingFileExist(url: folderURL)
        do {
            try await workSpaceStorage.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            self.notificationManager.showErrorMessage(error.localizedDescription)
            throw error
        }
    }

    func renameFile(url: URL, name: String) async throws {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(name)
        do {
            try await workSpaceStorage.moveItem(at: url, to: newURL)
        } catch let error {
            throw error
        }
        let editorsToRename = textEditors.filter {
            [url.absoluteString, url.absoluteURL.absoluteString]
                .contains($0.url.absoluteString)
        }
        for editor in editorsToRename {
            await MainActor.run {
                monacoInstance.renameModel(
                    oldURL: editor.url.absoluteString, newURL: url.absoluteString)
                editor.url = newURL
                editor.isDeleted = false
            }
        }
    }

    @MainActor
    func loadURLQueue() {
        Task {
            for url in urlQueue {
                _ = try? await openFile(url: url, alwaysInNewTab: true)
            }
            urlQueue = []
        }
    }

    func duplicateItem(at: URL) async throws {
        let destinationURL = try await workSpaceStorage.urlWithSuffixIfExistingFileExist(url: at)
        do {
            try await workSpaceStorage.copyItem(at: at, to: destinationURL)
        } catch {
            self.notificationManager.showErrorMessage(error.localizedDescription)
            throw error
        }
    }

    func trashItem(url: URL) {
        alertManager.showAlert(
            title: "file.confirm_delete \(url.lastPathComponent)",
            content: AnyView(
                Group {
                    Button("common.delete", role: .destructive) {
                        self.workSpaceStorage.removeItem(at: url) { error in
                            if let error = error {
                                self.notificationManager.showErrorMessage(
                                    error.localizedDescription)
                                return
                            }
                            if let editorToTrash = self.textEditors.first(where: { $0.url == url })
                            {
                                Task { @MainActor in
                                    self.closeEditor(editor: editorToTrash)
                                }
                            }
                        }
                    }
                    Button("common.cancel", role: .cancel) {}
                }
            ))
    }

    func decodeStringData(data: Data) throws -> (String, String.Encoding) {
        // Most popular encodings according to Wikipedia.
        // Although the list is not exhaustive,
        // other encoding will likely be decoded using one of these anyway.
        let encodingsToTry: [String.Encoding] = [
            .utf8, .windowsCP1250, .gb_18030_2000, .EUC_KR, .japaneseEUC,
        ]
        for encoding in encodingsToTry {
            if let str = String(data: data, encoding: encoding) {
                return (str, encoding)
            }
        }
        throw AppError.unknownFileFormat
    }

    func compareWithPrevious(url: URL) async throws {

        guard let provider = workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }

        let contentToCompareWith: String = try await withCheckedThrowingContinuation {
            continuation in
            provider.previous(
                path: url.absoluteString,
                error: {
                    continuation.resume(throwing: $0)
                },
                completionHandler: {
                    continuation.resume(returning: $0)
                })
        }

        try await compareWithContent(url: url, content: contentToCompareWith)
    }

    func compareWithSelected(url: URL) async throws {

        guard let selectedURLForCompare else { return }

        let data = try await workSpaceStorage.contents(at: url)
        let (content, _) = try decodeStringData(data: data)

        try await compareWithContent(url: selectedURLForCompare, content: content)
    }

    private func compareWithContent(url: URL, content: String) async throws {
        let data = try await workSpaceStorage.contents(at: url)
        let (original, encoding) = try decodeStringData(data: data)

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.scheme = "modified"

        let diffEditor = DiffTextEditorInstnace(
            editor: monacoInstance,
            url: components.url!,
            content: original,
            encoding: encoding,
            compareWith: content
        )

        await appendAndFocusNewEditor(editor: diffEditor, alwaysInNewTab: true)
    }

    func reloadCurrentFileWithEncoding(encoding: String.Encoding) {
        guard let activeTextEditor = activeEditor as? TextEditorInstance else {
            return
        }
        workSpaceStorage.contents(
            at: activeTextEditor.url,
            completionHandler: { data, error in
                guard let data = data else {
                    if let error = error {
                        self.notificationManager.showErrorMessage(error.localizedDescription)
                    }
                    return
                }
                if let string = String(data: data, encoding: encoding) {
                    activeTextEditor.encoding = encoding
                    activeTextEditor.content = string
                    Task {
                        try await self.monacoInstance.setValueForModel(
                            url: activeTextEditor.url, value: string)
                    }
                } else {
                    self.notificationManager.showErrorMessage(
                        "Failed to decode file with \(encoding.description).")
                }
            })
    }

    private func saveTextEditor(editor: TextEditorInstance, overwrite: Bool = false) async throws {

        if !overwrite {
            let attributes = try? await workSpaceStorage.attributesOfItem(at: editor.url)
            let modificationDate = attributes?[.modificationDate] as? Date
            if let modificationDate = modificationDate {
                if modificationDate > editor.lastSavedDate ?? Date.distantFuture {
                    throw AppError.fileModifiedByAnotherProcess
                }
            }
        }

        guard let data = editor.content.data(using: editor.encoding)
        else {
            throw AppError.encodingFailed
        }

        do {
            await MainActor.run {
                editor.isSaving = true
            }

            try await workSpaceStorage.write(
                at: editor.url, content: data, atomically: false, overwrite: true)

            let updatedAttributes = try? await workSpaceStorage.attributesOfItem(at: editor.url)
            let updatedModificationDate = updatedAttributes?[.modificationDate] as? Date
            await MainActor.run {
                editor.lastSavedDate = updatedModificationDate
                editor.lastSavedVersionId = editor.currentVersionId
                editor.isDeleted = false
                editor.isSaving = false
            }
        } catch {
            await MainActor.run {
                editor.isSaving = false
            }
            throw error
        }

        self.git_status()

        if self.editorSpellCheckEnabled && !self.editorSpellCheckOnContentChanged {
            await monacoInstance.checkSpelling(text: editor.content, uri: editor.url.absoluteString)
        }
    }

    func saveCurrentFile() {
        Task {
            await saveCurrentFile()
        }
    }

    func saveCurrentFile() async {
        if editors.isEmpty { return }
        guard let activeTextEditor = activeEditor as? TextEditorInstance else {
            return
        }
        if activeTextEditor.isSaved {
            return
        }
        do {
            try await saveTextEditor(editor: activeTextEditor)
        } catch AppError.fileModifiedByAnotherProcess {
            self.notificationManager.postActionNotification(
                title: AppError.fileModifiedByAnotherProcess.localizedDescription,
                level: .error,
                primary: {
                    Task {
                        try await self.compareWithContent(
                            url: activeTextEditor.url, content: activeTextEditor.content)
                    }
                },
                primaryTitle: "common.compare",
                secondary: {
                    Task {
                        try await self.saveTextEditor(editor: activeTextEditor, overwrite: true)
                    }
                },
                secondaryTitle: "common.overwrite",
                source: "Code App")
        } catch {
            self.notificationManager.showErrorMessage(error.localizedDescription)
        }
    }

    @MainActor
    func reloadDirectory() {
        guard let url = URL(string: workSpaceStorage.currentDirectory.url) else {
            return
        }
        loadFolder(url: url, resetEditors: false)
    }

    func git_status() {

        DispatchQueue.main.async {
            self.stateManager.gitServiceIsBusy = true
        }

        func onFinish() {
            DispatchQueue.main.async {
                self.stateManager.gitServiceIsBusy = false
            }
        }

        func clearUIState() {
            DispatchQueue.main.async {
                self.remote = ""
                self.branch = ""
                self.gitTracks = [:]
                self.indexedResources = [:]
                self.workingResources = [:]
            }
        }

        if workSpaceStorage.gitServiceProvider == nil {
            clearUIState()
        }

        workSpaceStorage.gitServiceProvider?.status(error: { _ in
            clearUIState()
            onFinish()
        }) { indexed, worktree, branch in
            guard let hasRemote = self.workSpaceStorage.gitServiceProvider?.hasRemote() else {
                onFinish()
                return
            }

            DispatchQueue.main.async {
                let indexedDictionary = Dictionary(uniqueKeysWithValues: indexed)
                let workingDictionary = Dictionary(uniqueKeysWithValues: worktree)

                if hasRemote {
                    self.remote = "origin"
                } else {
                    self.remote = ""
                }
                self.branch = branch
                self.indexedResources = indexedDictionary
                self.workingResources = workingDictionary

                self.gitTracks = indexedDictionary.merging(
                    workingDictionary,
                    uniquingKeysWith: { current, _ in
                        current
                    })
            }

            self.workSpaceStorage.gitServiceProvider?.aheadBehind(error: {
                print($0.localizedDescription)
                onFinish()
                DispatchQueue.main.async {
                    self.aheadBehind = nil
                }
            }) { result in
                onFinish()
                DispatchQueue.main.async {
                    self.aheadBehind = result
                }
            }
        }
    }

    func loadRepository(url: URL) {
        workSpaceStorage.gitServiceProvider?.loadDirectory(url: url.standardizedFileURL)
        git_status()
    }

    // Injecting JavaScript / TypeScript types
    func scanForTypes() {
        guard
            let typesURL = URL(string: workSpaceStorage.currentDirectory.url)?
                .appendingPathComponent("node_modules")
        else {
            return
        }
        self.monacoInstance.injectTypes(url: typesURL)
        editorTypesMonitor = FolderMonitor(url: typesURL)

        if FileManager.default.fileExists(atPath: typesURL.path) {
            editorTypesMonitor?.startMonitoring()
            editorTypesMonitor?.folderDidChange = { _ in
                self.monacoInstance.injectTypes(url: typesURL)
            }
        }
    }

    func loadFolder(url: URL, resetEditors: Bool = true) {
        if workSpaceStorage.remoteConnected && url.isFileURL {
            workSpaceStorage.disconnect()
        }

        ios_setDirectoryURL(url)
        scanForTypes()

        self.workSpaceStorage.updateDirectory(
            name: url.lastPathComponent, url: url.absoluteString)

        loadRepository(url: url)

        if let data = try? url.bookmarkData() {
            if var datas = UserDefaults.standard.value(forKey: "recentFolder") as? [Data] {
                var existingName: [String] = []
                for data in datas {
                    var isStale = false
                    if let newURL = try? URL(
                        resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
                    {
                        existingName.append(newURL.lastPathComponent)
                    }
                }
                if let index = existingName.firstIndex(of: url.lastPathComponent) {
                    datas.remove(at: index)
                }
                datas = [data] + datas
                if datas.count > 5 {
                    datas.removeLast()
                }
                UserDefaults.standard.setValue(datas, forKey: "recentFolder")

            } else {
                UserDefaults.standard.setValue([data], forKey: "recentFolder")
            }
        }
        if resetEditors {
            DispatchQueue.main.async {
                self.closeAllEditors()
                self.terminalInstance.resetAndSetNewRootDirectory(url: url)
            }
        }
        extensionManager.onWorkSpaceStorageChanged(newUrl: url)
    }

    private func createExtensionEditorFromURL(url: URL) throws -> EditorInstance {
        guard url.lastPathComponent.contains(".") else {
            throw AppError.unknownFileFormat
        }
        let fileExtension =
            url.lastPathComponent.components(separatedBy: ".").last?.lowercased() ?? ""
        let provider = extensionManager.editorProviderManager.providers.first {
            $0.registeredFileExtensions.contains(fileExtension)
        }

        guard let provider = provider else {
            throw AppError.unknownFileFormat
        }

        return provider.onCreateEditor(url)
    }

    private func createTextEditorFromURL(url: URL) async throws -> TextEditorInstance {
        // TODO: A more efficient way to determine whether file is supported
        let contentData: Data? = try await workSpaceStorage.contents(
            at: url
        )

        guard let contentData, let (content, encoding) = try? decodeStringData(data: contentData)
        else {
            throw AppError.unknownFileFormat
        }
        let attributes = try? await workSpaceStorage.attributesOfItem(at: url)
        let modificationDate = attributes?[.modificationDate] as? Date

        return TextEditorInstance(
            editor: monacoInstance,
            url: url,
            content: content,
            encoding: encoding,
            lastSavedDate: modificationDate,
            // TODO: Update using updateUIView?
            fileDidChange: { [weak self] state, content in
                if state == .modified, let content, let self {
                    Task {
                        try await self.monacoInstance.setValueForModel(url: url, value: content)
                    }
                }
            }
        )

    }

    private func openEditorForURL(url: URL) throws -> EditorInstanceWithURL {
        guard let editor = (editorsWithURL.first { $0.url == url }) else {
            throw AppError.editorDoesNotExist
        }

        activeEditor = editor

        return editor
    }

    @MainActor
    func closeAllEditors() {
        if editors.isEmpty {
            return
        }
        monacoInstance.removeAllModel()
        editors.removeAll(keepingCapacity: false)
        activeEditor = nil
    }

    @MainActor
    func appendAndFocusNewEditor(editor: EditorInstance, alwaysInNewTab: Bool = false) {
        var alwaysInNewTab = alwaysInNewTab
        if alwaysOpenInNewTab {
            alwaysInNewTab = true
        }
        if !alwaysInNewTab {
            if let activeTextEditor {
                if activeTextEditor.currentVersionId == 1,
                    activeTextEditor.isSaved
                {
                    editors.removeAll { $0 == activeTextEditor }
                }
            } else {
                editors.removeAll { $0 == activeEditor }
            }
        }

        editors.append(editor)
        activeEditor = editor
    }

    func openFile(url: URL, alwaysInNewTab: Bool = false) {
        Task {
            try await openFile(url: url, alwaysInNewTab: alwaysInNewTab)
        }
    }

    @MainActor
    @discardableResult
    func openFile(url: URL, alwaysInNewTab: Bool = false) async throws -> EditorInstance {
        guard stateManager.isMonacoEditorInitialized else {
            urlQueue.append(url)
            throw AppError.editorIsNotReady
        }
        var url = url
        if url.pathExtension == "icloud" {
            let originalFileName = String(
                url.lastPathComponent.dropFirst(".".count).dropLast(".icloud".count))
            url = url.deletingLastPathComponent().appendingPathComponent(originalFileName)
        }
        if let existingEditor = try? openEditorForURL(url: url) {
            return existingEditor
        }
        // TODO: Avoid reading the same file twice
        do {
            let textEditor = try await createTextEditorFromURL(url: url)
            appendAndFocusNewEditor(editor: textEditor, alwaysInNewTab: alwaysInNewTab)
            return textEditor
        } catch NSFileProviderError.serverUnreachable {
            throw NSFileProviderError(.serverUnreachable)
        } catch {
            // Otherwise, fallback to using extensions
            let editor = try createExtensionEditorFromURL(url: url)
            appendAndFocusNewEditor(editor: editor, alwaysInNewTab: alwaysInNewTab)
            return editor
        }
    }

    @MainActor
    func setActiveEditor(editor: EditorInstance) {
        activeEditor = editor
    }

    @MainActor
    func closeEditor(editor: EditorInstance, force: Bool = false) {
        if !force, let textEditor = editor as? TextEditorInstance, !textEditor.isSaved {
            alertManager.showAlert(
                title: "file.confirm_save \(textEditor.title)",
                content: AnyView(
                    Group {
                        Button("common.save") {
                            Task {
                                try await self.saveTextEditor(editor: textEditor)
                                self.closeEditor(editor: textEditor)
                            }
                        }

                        Button("common.dont_save", role: .destructive) {
                            Task {
                                let dataToRevertTo = try await self.workSpaceStorage.contents(
                                    at: textEditor.url)
                                guard
                                    let contentToRevertTo = String(
                                        data: dataToRevertTo, encoding: textEditor.encoding)
                                else {
                                    return
                                }
                                try await self.monacoInstance.setValueForModel(
                                    url: textEditor.url, value: contentToRevertTo)
                            }
                            self.closeEditor(editor: textEditor, force: true)
                        }

                        Divider()

                        Button("common.cancel", role: .cancel) {}
                    }
                ))
            return
        }
        guard let index = (editors.firstIndex { $0.id == editor.id }) else {
            return
        }
        if editors.indices.contains(index - 1) {
            activeEditor = editors[index - 1]
        } else if editors.indices.contains(index + 1) {
            activeEditor = editors[index + 1]
        } else {
            activeEditor = nil
        }

        editors.remove(at: index)
    }
}
