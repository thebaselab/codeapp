//
//  App.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import Combine
import CoreSpotlight
import os.log
import SwiftGit2
import SwiftUI
import UniformTypeIdentifiers
import ios_system

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Code", category: "MainApp")

struct CheckoutDestination: Identifiable {
    var id = UUID()
    var reference: ReferenceType

    var shortOID: String {
        String(self.reference.oid.description.dropLast(32))
    }
    var name: String {
        self.reference.shortName ?? self.reference.longName
    }
}

class CreateFileSheetManager: ObservableObject {
    @Published var showsSheet: Bool = false

    var targetURL: URL?

    func showSheet(targetURL: URL) {
        self.targetURL = targetURL
        showsSheet = true
    }
}

class DirectoryPickerManager: ObservableObject {
    @Published var showsPicker: Bool = false

    var callback: ((URL) -> Void)?
    var type: DirectoryPickerViewType = .directory

    func showPicker(type: DirectoryPickerViewType, callback: @escaping ((URL) -> Void)) {
        self.type = type
        self.callback = callback
        showsPicker = true
    }
}

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
    var message: LocalizedStringKey? = nil
    var alertContent: AnyView = AnyView(EmptyView())

    func showAlert(title: LocalizedStringKey, message: LocalizedStringKey? = nil, content: AnyView)
    {
        self.title = title
        self.alertContent = content
        self.message = message
        isShowingAlert = true
    }
}

class AuthenticationRequestManager: ObservableObject {
    @Published var isShowingAlert = false
    @Published var username = ""
    @Published var password = ""

    var title: LocalizedStringKey = ""
    var usernameTitleKey: LocalizedStringKey? = nil
    var passwordTitleKey: LocalizedStringKey? = nil
    var callback: (() -> Void) = {}
    var callbackOnCancel: (() -> Void) = {}

    @MainActor
    func requestPasswordAuthentication(
        title: LocalizedStringKey,
        usernameTitleKey: LocalizedStringKey? = nil,
        passwordTitleKey: LocalizedStringKey? = nil
    ) async throws -> (String, String) {
        self.title = title
        self.usernameTitleKey = usernameTitleKey
        self.passwordTitleKey = passwordTitleKey
        self.isShowingAlert = true

        return try await withCheckedThrowingContinuation { continuation in
            callback = {
                continuation.resume(returning: (self.username, self.password))
                self.username = ""
                self.password = ""
                self.title = ""
                self.usernameTitleKey = nil
                self.passwordTitleKey = nil
                self.callback = {}
                self.callbackOnCancel = {}
            }
            callbackOnCancel = {
                continuation.resume(throwing: AppError.operationCancelledByUser)
                self.username = ""
                self.password = ""
                self.title = ""
                self.usernameTitleKey = nil
                self.passwordTitleKey = nil
                self.callback = {}
                self.callbackOnCancel = {}
            }
        }
    }
}

class MainStateManager: ObservableObject {
    @Published var showsNewFileSheet = false
    @Published var showsDirectoryPicker = false
    @Published var showsFilePicker = false
    @Published var showsChangeLog: Bool = false
    @Published var showsSettingsSheet: Bool = false
    @Published var showsCheckoutAlert: Bool = false
    @Published var availableCheckoutDestination: [CheckoutDestination] = []
    @Published var gitServiceIsBusy = false
    @Published var isMonacoEditorInitialized = false
    @Published var isSystemExtensionsInitialized = false
}

class MainApp: ObservableObject {
    let extensionManager = ExtensionManager()
    let stateManager = MainStateManager()
    let alertManager = AlertManager()
    let safariManager = SafariManager()
    let directoryPickerManager = DirectoryPickerManager()
    let createFileSheetManager = CreateFileSheetManager()
    let authenticationRequestManager = AuthenticationRequestManager()

    @Published var editors: [EditorInstance] = []
    var textEditors: [TextEditorInstance] {
        editors.filter { $0 is TextEditorInstance } as? [TextEditorInstance] ?? []
    }
    var editorsWithURL: [EditorInstanceWithURL] {
        editors.filter { $0 is EditorInstanceWithURL } as? [EditorInstanceWithURL] ?? []
    }

    @Published var isShowingCompilerLanguage = false
    @Published var activeEditor: EditorInstance? = nil {
        didSet {
            if let activeEditor = activeEditor as? EditorInstanceWithURL {
                workSpaceStorage.cellState.highlightedCells = Set([activeEditor.url.absoluteString])
            } else {
                workSpaceStorage.cellState.highlightedCells.removeAll()
            }
            Task {
                await updateActiveEditor()
            }
        }
    }
    var activeTextEditor: TextEditorInstance? {
        activeEditor as? TextEditorInstance
    }

    @Published var selectedURLForCompare: URL? = nil
    @Published var notificationManager = NotificationManager()
    @Published var searchManager = GitHubSearchManager()
    @Published var textSearchManager = TextSearchManager()
    @Published var workSpaceStorage: WorkSpaceStorage

    // Editor States
    @Published var problems: [URL: [MonacoEditorMarker]] = [:]

    // Git UI states
    @Published var gitTracks: [URL: Diff.Status] = [:]
    @Published var indexedResources: [URL: Diff.Status] = [:]
    @Published var workingResources: [URL: Diff.Status] = [:]
    @Published var branch: String = ""
    @Published var commitMessage: String = ""
    @Published var isSyncing: Bool = false
    @Published var aheadBehind: (Int, Int)? = nil

    var urlQueue: [URL] = []
    var editorShortcuts: [MonacoEditorAction] = []
    var monacoStateToRestore: String? = nil

    let terminalManager: TerminalManager
    var monacoInstance: EditorImplementation! = nil

    // Backward compatibility: returns the active terminal
    var terminalInstance: TerminalInstance! {
        terminalManager.activeTerminal
    }
    var editorTypesMonitor: FolderMonitor? = nil
    let deviceSupportsBiometricAuth: Bool = biometricAuthSupported()
    let sceneIdentifier = UUID()

    private var NotificationCancellable: AnyCancellable? = nil
    private var CompilerCancellable: AnyCancellable? = nil
    private var searchCancellable: AnyCancellable? = nil
    private var textSearchCancellable: AnyCancellable? = nil
    private var workSpaceCancellable: AnyCancellable? = nil
    private var cancellables = Set<AnyCancellable>()
    private var isConfiguringOpenEditors = false

    @AppStorage("alwaysOpenInNewTab") var alwaysOpenInNewTab: Bool = false
    @AppStorage("explorer.confirmBeforeDelete") var confirmBeforeDelete = false
    @AppStorage("editorOptions") var editorOptions: CodableWrapper<EditorOptions> = .init(
        value: EditorOptions())
    @AppStorage("terminalOptions") var terminalOptions: CodableWrapper<TerminalOptions> = .init(
        value: TerminalOptions())
    @AppStorage("editorLightTheme") var selectedLightTheme: String = "Light+"
    @AppStorage("editorDarkTheme") var selectedTheme: String = "Dark+"
    @AppStorage("stateRestorationEnabled") var stateRestorationEnabled = true
    @AppStorage("runeStoneEditorEnabled") var runeStoneEditorEnabled: Bool = false
    @AppStorage("languageServiceEnabled") var languageServiceEnabled: Bool = true

    init() {

        let rootDir: URL = getRootDirectory()

        self.workSpaceStorage = WorkSpaceStorage(url: rootDir)

        // Use helper to read options before self is fully initialized
        let options = TerminalManager.readTerminalOptionsFromDefaults()
        self.terminalManager = TerminalManager(rootURL: rootDir, options: options)
        setUpEditorInstance()

        // Set up openEditor callback for initial terminal
        configureOpenEditorForTerminals()

        // Forward terminalManager changes to MainApp so UI updates
        terminalManager.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.objectWillChange.send()
                // Set up openEditor for any new terminals
                self.scheduleConfigureOpenEditorForTerminals()
            }
        }.store(in: &cancellables)

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
                self?.updateGitRepositoryStatus()
            }
        }
        workSpaceStorage.onTerminalData { [weak self] data in
            guard let self = self else { return }
            // Use the tracked remote terminal for consistent data routing
            if let terminal = self.terminalManager.remoteTerminal {
                terminal.write(data: data)
            } else {
                logger.warning("Remote terminal data dropped: no remote terminal available (\(data.count) bytes)")
            }
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

        updateGitRepositoryStatus()

        Task {
            await MainActor.run {
                setUpActivityBarItems()
                stateManager.isSystemExtensionsInitialized = true
            }
        }
    }

    func setUpEditorInstance() {
        stateManager.isMonacoEditorInitialized = false
        if runeStoneEditorEnabled {
            monacoInstance = RunestoneImplementation(
                options: editorOptions.value,
                theme: EditorTheme(dark: ThemeManager.darkTheme, light: ThemeManager.lightTheme))
        } else {
            monacoInstance = MonacoImplementation(
                options: editorOptions.value,
                theme: EditorTheme(dark: ThemeManager.darkTheme, light: ThemeManager.lightTheme))
        }
        monacoInstance.delegate = self
        for textEditor in textEditors {
            textEditor.view = AnyView(EditorImplementationView(implementation: monacoInstance))
        }
    }

    private func configureOpenEditorForTerminals() {
        for terminal in terminalManager.terminals where terminal.openEditor == nil {
            terminal.openEditor = { [weak self] url in
                if url.isDirectory {
                    DispatchQueue.main.async {
                        self?.loadFolder(url: url)
                    }
                } else {
                    self?.openFile(url: url)
                }
            }
        }
    }

    private func scheduleConfigureOpenEditorForTerminals() {
        guard !isConfiguringOpenEditors else { return }
        isConfiguringOpenEditors = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.configureOpenEditorForTerminals()
            self.isConfiguringOpenEditors = false
        }
    }

    private func updateActiveEditor() async {
        guard let activeTextEditor else {
            Task {
                await monacoInstance.setModelToEmpty()
            }
            return
        }
        if let diffEditor = activeTextEditor as? DiffTextEditorInstnace {
            let diffURL = URL(string: "git://" + diffEditor.url.path)!
            await monacoInstance.switchToDiffMode(
                originalContent: diffEditor.compareWith, modifiedContent: diffEditor.content,
                originalUrl: diffURL.absoluteString, modifiedUrl: diffEditor.url.absoluteString)
        } else {
            Task {
                if await monacoInstance.isEditorInDiffMode() {
                    await monacoInstance.switchToNormalMode()
                }
                await monacoInstance.createNewModel(
                    url: activeTextEditor.url.absoluteString, value: activeTextEditor.content)
            }
        }

        guard let currentDirectoryURL = workSpaceStorage.currentDirectory._url else {
            return
        }
        guard !runeStoneEditorEnabled && currentDirectoryURL.isFileURL && languageServiceEnabled
        else {
            monacoInstance.disconnectLanguageService()
            return
        }
        if let languageServiceConfiguration = LanguageService.configurationFor(
            url: activeTextEditor.url)
        {
            Task {
                let isLanguageServiceConnected = await monacoInstance.isLanguageServiceConnected
                if isLanguageServiceConnected
                    && LanguageService.shared.candidateLanguageIdentifier
                        == languageServiceConfiguration.languageIdentifier
                {
                    return
                }
                if isLanguageServiceConnected {
                    monacoInstance.disconnectLanguageService()
                    try? await Task.sleep(for: .seconds(5))
                }
                LanguageService.shared.candidateLanguageIdentifier =
                    languageServiceConfiguration.languageIdentifier
                monacoInstance.connectLanguageService(
                    serverURL: URL(
                        string: "ws://127.0.0.1:\(String(AppExtensionService.PORT))/websocket")!,
                    serverArgs: languageServiceConfiguration.args,
                    pwd: currentDirectoryURL,
                    languageIdentifier: languageServiceConfiguration.languageIdentifier
                )
            }
        }
    }

    @MainActor
    private func setUpActivityBarItems() {

        let openFile = {
            self.stateManager.showsFilePicker.toggle()
        }
        let openNewFile = {
            self.stateManager.showsNewFileSheet.toggle()
        }
        let openFolder = {
            self.stateManager.showsDirectoryPicker = true
        }

        let explorer = ActivityBarItem(
            itemID: "EXPLORER",
            iconSystemName: "doc.on.doc",
            title: "Explorer",
            shortcutKey: "e",
            modifiers: [.command, .shift],
            view: AnyView(ExplorerContainer()),
            contextMenuItems: {
                [
                    ContextMenuItem(
                        action: openNewFile, text: "New File",
                        imageSystemName: "doc.badge.plus"),
                    ContextMenuItem(
                        action: openFile, text: "Open File",
                        imageSystemName: "doc"),
                ]
                    + (self.workSpaceStorage.remoteConnected
                        ? []
                        : [
                            ContextMenuItem(
                                action: openFolder,
                                text: "Open Folder",
                                imageSystemName: "folder.badge.gear"
                            )
                        ])
            },
            bubble: { nil },
            isVisible: { true }
        )
        let search = ActivityBarItem(
            itemID: "SEARCH",
            iconSystemName: "magnifyingglass",
            title: "Search",
            shortcutKey: "f",
            modifiers: [.command, .shift],
            view: AnyView(SearchContainer()),
            contextMenuItems: nil,
            bubble: { nil },
            isVisible: { true }
        )
        let sourceControl = ActivityBarItem(
            itemID: "SOURCE_CONTROL",
            iconSystemName:
                "point.topleft.down.curvedto.point.bottomright.up",
            title: "Source Control",
            shortcutKey: "g",
            modifiers: [.control, .shift],
            view: AnyView(SourceControlContainer()),
            contextMenuItems: nil,
            bubble: {
                if self.stateManager.gitServiceIsBusy {
                    return .systemImage("clock")
                } else {
                    return self.gitTracks.isEmpty ? nil : .text("\(self.gitTracks.count)")
                }
            },
            isVisible: { true }
        )
        let remote = ActivityBarItem(
            itemID: "REMOTE",
            iconSystemName: "rectangle.connected.to.line.below",
            title: "Remotes",
            shortcutKey: "r",
            modifiers: [.command, .shift],
            view: AnyView(RemoteContainer()),
            contextMenuItems: nil,
            bubble: { self.workSpaceStorage.remoteConnected ? .text("") : nil },
            isVisible: { true }
        )

        extensionManager.activityBarManager.registerItem(item: explorer)
        extensionManager.activityBarManager.registerItem(item: search)
        extensionManager.activityBarManager.registerItem(item: sourceControl)
        extensionManager.activityBarManager.registerItem(item: remote)

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
            await monacoInstance.renameModel(
                oldURL: editor.url.absoluteString, updatedURL: url.absoluteString)
            editor.url = newURL
            editor.isDeleted = false
        }
    }

    @MainActor
    func loadURLQueue() async {
        for url in urlQueue {
            _ = try? await openFile(url: url, alwaysInNewTab: true)
        }
        urlQueue = []
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

    func moveFile(fromUrl: URL, toUrl: URL) {
        func move() {
            Task {
                do {
                    try await workSpaceStorage.moveItem(at: fromUrl, to: toUrl)
                } catch {
                    notificationManager.showErrorMessage(error.localizedDescription)
                }
            }
        }

        if !fromUrl.isFileURL {
            alertManager.showAlert(
                title:
                    "file.confirm_move_into \(fromUrl.lastPathComponent) \(toUrl.deletingLastPathComponent().lastPathComponent)",
                content: AnyView(
                    Group {
                        Button("common.move") {
                            move()
                        }
                        Button("common.cancel", role: .cancel) {}
                    }
                ))
        } else {
            move()
        }
    }

    func trashItem(url: URL) {
        func removeItem() {
            self.workSpaceStorage.removeItem(at: url) { error in
                if let error = error {
                    self.notificationManager.showErrorMessage(
                        error.localizedDescription)
                    return
                }
                if let editorToTrash = self.textEditors.first(where: { $0.url == url }) {
                    Task { @MainActor in
                        self.closeEditor(editor: editorToTrash)
                    }
                }
            }
        }

        if !confirmBeforeDelete {
            removeItem()
            return
        }

        alertManager.showAlert(
            title: "file.confirm_delete \(url.lastPathComponent)",
            content: AnyView(
                Group {
                    Button("common.delete", role: .destructive) {
                        removeItem()
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
        if let existingEditor = editorsWithURL.first(where: {
            $0 is DiffTextEditorInstnace && $0.url == url
        }) {
            await MainActor.run {
                activeEditor = existingEditor
            }
            return
        }
        guard let provider = workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }
        let contentToCompareWith = try await provider.previous(path: url.absoluteString)
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
        let diffEditor = DiffTextEditorInstnace(
            editor: monacoInstance,
            url: url,
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
                        await self.monacoInstance.setValueForModel(
                            url: activeTextEditor.url.absoluteString, value: string)
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

        self.updateGitRepositoryStatus()
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

    private func groupStatusEntries(entries: [StatusEntry]) -> (
        [(URL, Diff.Status)], [(URL, Diff.Status)]
    ) {
        var indexedGroup = [(URL, Diff.Status)]()
        var workingGroup = [(URL, Diff.Status)]()

        let workingURL = workSpaceStorage.currentDirectory._url!

        for i in entries {
            let status = i.status

            let headToIndexURL: URL? = {
                guard let path = i.headToIndex?.newFile?.path else {
                    return nil
                }
                return workingURL.appendingPathComponent(path)
            }()
            let indexToWorkURL: URL? = {
                guard let path = i.indexToWorkDir?.newFile?.path else {
                    return nil
                }
                return workingURL.appendingPathComponent(path)
            }()

            status.allIncludedCases.forEach { includedCase in
                if [
                    .indexDeleted, .indexRenamed, .indexModified, .indexDeleted,
                    .indexTypeChange, .indexNew,
                ].contains(includedCase) {
                    indexedGroup.append((headToIndexURL!, includedCase))
                } else if [
                    .workTreeNew, .workTreeDeleted, .workTreeRenamed, .workTreeModified,
                    .workTreeUnreadable, .workTreeTypeChange, .conflicted,
                ].contains(includedCase) {
                    workingGroup.append((indexToWorkURL!, includedCase))
                }
            }
        }
        return (indexedGroup, workingGroup)
    }

    func updateGitRepositoryStatus() {

        DispatchQueue.main.async {
            self.stateManager.gitServiceIsBusy = true
        }

        @Sendable func onFinish() {
            DispatchQueue.main.async {
                self.stateManager.gitServiceIsBusy = false
            }
        }

        @Sendable func clearUIState() {
            DispatchQueue.main.async {
                self.aheadBehind = nil
                self.branch = ""
                self.gitTracks = [:]
                self.indexedResources = [:]
                self.workingResources = [:]
            }
        }

        guard let gitServiceProvider = workSpaceStorage.gitServiceProvider else {
            clearUIState()
            onFinish()
            return
        }

        Task {
            defer {
                onFinish()
            }
            do {
                let entries = try await gitServiceProvider.status()
                let (indexed, worktree) = groupStatusEntries(entries: entries)

                let indexedDictionary = Dictionary(uniqueKeysWithValues: indexed)
                let workingDictionary = Dictionary(uniqueKeysWithValues: worktree)

                await MainActor.run {
                    self.indexedResources = indexedDictionary
                    self.workingResources = workingDictionary
                    self.gitTracks = indexedDictionary.merging(
                        workingDictionary,
                        uniquingKeysWith: { current, _ in
                            current
                        })
                }

                let aheadBehind = try? await gitServiceProvider.aheadBehind(remote: nil)
                let currentHead = try await gitServiceProvider.head()

                await MainActor.run {
                    self.aheadBehind = aheadBehind

                    var branchLabel: String
                    if let currentBranch = currentHead as? Branch {
                        branchLabel = currentBranch.name
                    } else {
                        branchLabel = String(currentHead.oid.description.prefix(7))
                    }

                    if entries.first(where: { $0.status.contains(.workTreeModified) }) != nil {
                        branchLabel += "*"
                    }
                    if entries.first(where: { $0.status.contains(.indexModified) }) != nil {
                        branchLabel += "+"
                    }
                    if entries.first(where: { $0.status.contains(.conflicted) }) != nil {
                        branchLabel += "!"
                    }

                    self.branch = branchLabel
                }
            } catch {
                clearUIState()
            }
        }

        Task {
            let references: [ReferenceType] =
                (try await gitServiceProvider.tags())
                + (try await gitServiceProvider.remoteBranches())
                + (try await gitServiceProvider.localBranches())
            await MainActor.run {
                self.stateManager.availableCheckoutDestination = references.map {
                    CheckoutDestination(reference: $0)
                }
            }
        }
    }

    func loadRepository(url: URL) {
        workSpaceStorage.gitServiceProvider?.loadDirectory(url: url)
        updateGitRepositoryStatus()
    }

    func loadFolder(url: URL, resetEditors: Bool = true) {
        let url = url.standardizedFileURL
        if workSpaceStorage.remoteConnected && url.isFileURL {
            workSpaceStorage.disconnect()
        }

        ios_setDirectoryURL(url)

        self.workSpaceStorage.updateDirectory(
            name: url.lastPathComponent, url: url.absoluteString)

        loadRepository(url: url)

        if url.isFileURL,
            let newBookmark = try? url.bookmarkData()
        {
            if var bookmarks = UserDefaults.standard.value(forKey: "recentFolder") as? [Data] {
                bookmarks = bookmarks.filter {
                    var isStale = false
                    guard
                        let newURL = try? URL(
                            resolvingBookmarkData: $0, bookmarkDataIsStale: &isStale)
                    else {
                        return false
                    }
                    // We do not have a stable identity of a url due to sandboxing, compare lastPathComponent instead
                    return (newURL.lastPathComponent != url.lastPathComponent && !isStale)
                }
                bookmarks = [newBookmark] + bookmarks
                if bookmarks.count > 5 {
                    bookmarks.removeLast()
                }
                UserDefaults.standard.setValue(bookmarks, forKey: "recentFolder")
            } else {
                UserDefaults.standard.setValue([newBookmark], forKey: "recentFolder")
            }
        }
        if resetEditors {
            DispatchQueue.main.async {
                self.closeAllEditors()
                self.terminalManager.resetAndSetNewRootDirectory(url: url)
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
                        await self.monacoInstance.setValueForModel(
                            url: url.absoluteString, value: content)
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
        Task {
            await monacoInstance.removeAllModels()
        }
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
            if urlQueue.contains(url) {
                urlQueue.removeAll { $0 == url }
            }
            urlQueue.append(url)
            throw AppError.editorIsNotReady
        }
        var url = url.standardizedFileURL
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
        guard let editor = editor as? EditorInstanceWithURL else {
            return
        }

        var url = editor.url
        url.deleteLastPathComponent()
        while url != workSpaceStorage.currentDirectory._url {
            workSpaceStorage.expandedCells.insert(url.absoluteString)
            let originalLength = url.absoluteString.count
            url.deleteLastPathComponent()
            if url.absoluteString.count >= originalLength {
                break
            }
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("explorer.scrollto"), object: nil,
                userInfo: [
                    "sceneIdentifier": self.sceneIdentifier, "target": editor.url.absoluteString,
                ])
        }

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
                                await self.monacoInstance.setValueForModel(
                                    url: textEditor.url.absoluteString, value: contentToRevertTo)
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

    func isUibiquitousItem(at url: URL) -> Bool {
        return FileManager.default.isUbiquitousItem(at: url)
    }

    func downloadUibiquitousItem(at url: URL) throws {
        if !url.isDirectory {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        } else {
            let enumerator = FileManager.default.enumerator(
                at: url, includingPropertiesForKeys: nil)
            while let fileURL = enumerator?.nextObject() as? URL {
                try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
            }
        }

    }
}

extension MainApp: EditorImplementationDelegate {
    func didEnterFocus() {
        let notification = Notification(
            name: Notification.Name("editor.focus"),
            userInfo: ["sceneIdentifier": sceneIdentifier]
        )
        NotificationCenter.default.post(notification)
    }

    func didFinishInitialising() {
        Task { @MainActor in
            for textEditor in self.textEditors {
                await monacoInstance.createNewModel(
                    url: textEditor.url.absoluteString, value: textEditor.content)
            }
            if let activeURL = activeTextEditor?.url {
                await monacoInstance.setModel(url: activeURL.absoluteString)
            }

            if stateRestorationEnabled, let monacoStateToRestore {
                await monacoInstance._restoreEditorState(state: monacoStateToRestore)
            }

            editorShortcuts = await monacoInstance._getMonacoActions()

            self.stateManager.isMonacoEditorInitialized = true
            await loadURLQueue()
        }
    }

    func editorImplementation(requestTextForDiffForModelURL url: String, ignoreCache: Bool)
        async -> String?
    {
        guard
            let sanitizedUri = URL(string: url)?.absoluteString
                .removingPercentEncoding,
            let gitServiceProvider = workSpaceStorage.gitServiceProvider
        else {
            return nil
        }

        // If the cache hasn't been invalidated, it means the editor also have the up-to-date model.
        if gitServiceProvider.isCached(url: sanitizedUri) && !ignoreCache {
            return nil
        }
        guard gitServiceProvider.hasRepository else { return nil }

        return try? await gitServiceProvider.previous(path: sanitizedUri)
    }

    func editorImplementation(
        contentDidChangeForModelURL url: String, content: String, versionID: Int
    ) {
        // TODO: This can be made more robust
        activeTextEditor?.currentVersionId = versionID
        activeTextEditor?.content = content
    }

    func editorImplementation(cursorPositionDidChange line: Int, column: Int) {
        NotificationCenter.default.post(
            name: Notification.Name("monaco.cursor.position.changed"), object: nil,
            userInfo: [
                "lineNumber": line, "column": column,
                "sceneIdentifier": sceneIdentifier,
            ])
    }

    func editorImplementation(onOpenURL url: String) {
        if let url = URL(string: url) {
            if url.scheme == "http" || url.scheme == "https" {
                safariManager.showSafari(url: url)
            }
        }
    }

    func editorImplementation(languageServerDidDisconnect languageIdentifier: String) {
        // Recovery strategy
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            Task {
                if !(await self.monacoInstance.isLanguageServiceConnected)
                    && languageIdentifier == LanguageService.shared.candidateLanguageIdentifier
                {
                    await self.updateActiveEditor()
                }
            }
        }
    }

    func editorImplementation(markersDidUpdate markers: [MonacoEditorMarker]) {
        problems = [:]
        for marker in markers {
            if let sanitisedURL = marker.resource.path.dropFirst().removingPercentEncoding,
                let url = URL(string: sanitisedURL)
            {
                if problems[url] != nil {
                    problems[url]!.append(marker)
                } else {
                    problems[url] = [marker]
                }
            }
        }
    }

    func editorImplementation(vimModeEvent id: String, userInfo: [String: Any]) {
        var userInfo = userInfo
        userInfo["sceneIdentifier"] = sceneIdentifier
        NotificationCenter.default.post(
            name: Notification.Name(id), object: nil,
            userInfo: userInfo)
    }

}
