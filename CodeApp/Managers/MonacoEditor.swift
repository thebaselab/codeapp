//
//  monacoEditor.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import GameController
import SwiftUI
import WebKit

struct MonacoEditor: UIViewRepresentable {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var themeManager: ThemeManager

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @AppStorage("editorFontSize") var fontSize: Int = 14
    @AppStorage("editorFontFamily") var fontFamily: String = "Menlo"
    @AppStorage("fontLigatures") var fontLigatures: Bool = false
    @AppStorage("quoteAutoCompletionEnabled") var bracketCompletionEnabled: Bool = true
    @AppStorage("editorMiniMapEnabled") var miniMapEnabled: Bool = true
    @AppStorage("editorLineNumberEnabled") var editorLineNumberEnabled: Bool = true
    @AppStorage("editorShowKeyboardButtonEnabled") var editorShowKeyboardButtonEnabled: Bool = true
    @AppStorage("editorTabSize") var edtorTabSize: Int = 4
    @AppStorage("editorRenderWhitespace") var renderWhitespace: Int = 2
    @AppStorage("editorLightTheme") var editorLightTheme: String = "Default"
    @AppStorage("editorDarkTheme") var editorDarkTheme: String = "Default"
    @AppStorage("editorWordWrap") var editorWordWrap: String = "off"
    @AppStorage("preferredColorScheme") var preferredScheme: Int = 0
    @AppStorage("toolBarEnabled") var toolBarEnabled: Bool = true
    @AppStorage("editorSmoothScrolling") var editorSmoothScrolling: Bool = false
    @AppStorage("editorReadOnly") var editorReadOnly = false
    @AppStorage("editorSpellCheckEnabled") var editorSpellCheckEnabled = false
    @AppStorage("editorSpellCheckOnContentChanged") var editorSpellCheckOnContentChanged = true
    @AppStorage("stateRestorationEnabled") var stateRestorationEnabled = true
    @SceneStorage("activeEditor.monaco.state") var activeEditorMonacoState: String?

    let monacoWebView = WebViewBase()

    func invalidateDecorations() {
        self.executeJavascript(command: "invalidateDecorations()")
    }

    func provideOriginalTextForUri(uri: String, value: String) {
        guard let encoded = value.base64Encoded() else {
            return
        }
        self.executeJavascript(
            command: "provideOriginalTextForUri(`\(uri)`, `\(encoded)`)", printResponse: true)
    }

    func renameModel(oldURL: String, newURL: String) {
        self.executeJavascript(command: "renameModel(`\(oldURL)`,`\(newURL)`)")
    }

    func getCurrentModelURI() -> String {
        var urlString = ""
        monacoWebView.evaluateJavaScript("editor.getModel().uri.path;") { (result, error) in
            if let url = result as? String {
                urlString = String(url.dropFirst())
            }
        }
        return urlString
    }

    func searchByTerm(term: String) {
        guard let encoded = term.base64Encoded() else {
            return
        }
        self.executeJavascript(
            command: "var decodedCommand = decodeURIComponent(escape(window.atob('\(encoded)')))")
        self.executeJavascript(
            command: "var range = editor.getModel().findMatches(decodedCommand)[0].range")
        self.executeJavascript(command: "editor.setSelection(range)")
        self.executeJavascript(command: "editor.getAction('actions.find').run()")
    }

    func scrollToLine(line: Int) {
        self.executeJavascript(command: "editor.revealLine(\(String(line)));")
    }

    func applyOptions(options: String) {
        self.executeJavascript(command: "editor.updateOptions({\(options)})")
    }

    func applyUserOptions() {
        applyOptions(options: "automaticLayout: true, lineNumbersMinChars: 5")

        executeJavascript(command: "editor.updateOptions({fontSize: \(String(fontSize))})")
        executeJavascript(
            command: "editor.updateOptions({fontFamily: \"\(fontFamily)\"})")
        executeJavascript(
            command: "editor.updateOptions({fontLigatures: \(String(fontLigatures))})")

        if !bracketCompletionEnabled {
            executeJavascript(command: "editor.updateOptions({ autoClosingBrackets: false });")
        }
        if !miniMapEnabled {
            executeJavascript(command: "editor.updateOptions({minimap: {enabled: false}})")
        }
        if !editorLineNumberEnabled {
            executeJavascript(command: "editor.updateOptions({ lineNumbers: false })")
        }
        if editorSmoothScrolling {
            executeJavascript(command: "editor.updateOptions({ smoothScrolling: true })")
        }
        if editorReadOnly {
            executeJavascript(command: "editor.updateOptions({ readOnly: true })")
        }
        executeJavascript(command: "editor.updateOptions({tabSize: \(String(edtorTabSize))})")
        let renderWhitespaceOptions = ["None", "Boundary", "Selection", "Trailing", "All"]
        executeJavascript(
            command:
                "editor.updateOptions({renderWhitespace: '\(String(renderWhitespaceOptions[renderWhitespace]).lowercased())'})"
        )
        executeJavascript(command: "editor.updateOptions({wordWrap: '\(editorWordWrap)'})")
    }

    func removeAllModel() {
        self.executeJavascript(
            command: "monaco.editor.getModels().forEach(model => model.dispose());")
    }

    func removeModel(url: String) {
        self.executeJavascript(
            command: "monaco.editor.getModel(monaco.Uri.parse('\(url)')).dispose();")
    }

    func updateModelContent(url: String, content: String) {
        guard let encoded = content.base64Encoded() else {
            return
        }
        self.executeJavascript(
            command: "var decodedCommand = decodeURIComponent(escape(window.atob('\(encoded)')))")
        self.executeJavascript(
            command: "monaco.editor.getModel(monaco.Uri.parse('\(url)')).setValue(decodedCommand)")
    }

    func setModel(url: String) {
        self.executeJavascript(
            command: "editor.setModel(monaco.editor.getModel(monaco.Uri.parse('\(url)')));")
    }

    func setModel(from: String, url: String) {
        self.executeJavascript(command: "states['\(from)'] = editor.saveViewState();")
        self.executeJavascript(
            command: "editor.setModel(monaco.editor.getModel(monaco.Uri.parse('\(url)')));")
    }

    func newModel(url: String, content: String) {
        guard url != "welcome.md{welcome}" else {
            return
        }
        self.executeJavascript(
            command: "states[editor.getModel().uri._formatted] = editor.saveViewState()")
        let encoded = content.base64Encoded()!
        self.executeJavascript(
            command: "var decodedCommand = decodeURIComponent(escape(window.atob('\(encoded)')))")
        self.executeJavascript(
            command:
                "editor.setModel(monaco.editor.createModel(decodedCommand, undefined, monaco.Uri.parse('\(url)')));"
        )
        if editorSpellCheckEnabled {
            checkSpelling(text: content, uri: url)
        }
    }

    func checkSpelling(text: String, uri: String, startOffset: Int = 0, endOffset: Int = 0) {

        SpellChecker.shared.check(
            text: text, uri: uri,
            cb: { spellProblems in
                if spellProblems.isEmpty, endOffset != 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        monacoWebView.evaluateJavaScript(
                            "invalidateDiagnosticForOffset(\(startOffset), \(endOffset))"
                        ) {
                            result, error in

                        }
                    }
                    return
                }

                let jsonData = try! JSONEncoder().encode(spellProblems)
                let jsonStr = String(data: jsonData, encoding: .utf8)!
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    monacoWebView.evaluateJavaScript(
                        "provideDiagnostic(\(jsonStr), '\(uri)')"
                    ) {
                        result, error in

                    }
                }
            })
    }

    func switchToDiffView(
        originalContent: String, modifiedContent: String, url: String, url2: String
    ) {
        let original = originalContent.base64Encoded()!
        let modified = modifiedContent.base64Encoded()!
        self.executeJavascript(
            command: "switchToDiffView('\(original)','\(modified)','\(url)','\(url2)')")

    }

    func switchToNormView() {
        self.executeJavascript(command: "switchToNormalView();")
    }

    func setTheme(themeName: String, data: String, isDark: Bool) {
        let themeName = themeName.replacingOccurrences(
            of: "[^A-Za-z0-9]+", with: "", options: [.regularExpression])

        if let base64 = data.base64Encoded() {
            self.executeJavascript(
                command:
                    "applyBase64AsTheme('\(base64)', '\(themeName)', \(isDark ? "true" : "false"))")
        }

        if let bundlePath = Bundle.main.path(forResource: "monaco-final", ofType: "bundle"),
            let bundle = Bundle(path: bundlePath),
            let url = bundle.url(
                forResource: themeName, withExtension: "json", subdirectory: "themes"),
            let data = try? Data(contentsOf: url),
            let string = String(data: data, encoding: .utf8),
            let base64 = string.base64Encoded()
        {
            self.executeJavascript(command: "applyBase64AsTheme('\(base64)', '\(themeName)');")
        }
    }

    func showKeyboard() {
        self.executeJavascript(command: "editor.focus()")
    }

    func executeJavascript(command: String, printResponse: Bool = false) {
        DispatchQueue.main.async {
            monacoWebView.evaluateJavaScript(command) { (result, error) in
                if printResponse {
                    print("Javascript: \(command) -> \(String(describing: result))")
                }
                if error != nil {
                    if printResponse {
                        print("[Error] Javascript: \(command) -> \(String(describing: error))")
                    }
                }
            }
        }
    }

    func injectTypes(url: URL) {
        var files = [URL]()
        if let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants])
        {
            for case let fileURL as URL in enumerator {
                do {
                    let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                    if fileAttributes.isRegularFile!, fileURL.absoluteString.hasSuffix("d.ts") {
                        files.append(fileURL)
                    }
                } catch { print(error, fileURL) }
            }
        }
        for file in files {
            guard
                let encodedContent = try? String(contentsOf: file, encoding: .utf8).base64Encoded()
            else {
                continue
            }
            var path = file.absoluteString
            if !file.absoluteString.contains("@types"), file.absoluteString.contains("node_modules")
            {
                path = path.replacingOccurrences(of: "node_modules", with: "node_modules/@types")
            }
            self.executeJavascript(
                command:
                    "monaco.languages.typescript.javascriptDefaults.addExtraLib(decodeURIComponent(escape(window.atob('\(encodedContent)'))),'\(path)')",
                printResponse: false)
            self.executeJavascript(
                command:
                    "monaco.languages.typescript.typescriptDefaults.addExtraLib(decodeURIComponent(escape(window.atob('\(encodedContent)'))),'\(path)')",
                printResponse: false)
        }
    }

    func applyCustomShortcuts() {
        if let result = UserDefaults.standard.value(forKey: "thebaselab.custom.keyboard.shortcuts")
            as? [String: [GCKeyCode]]
        {
            for entry in result {
                let gcCodes = entry.value
                var key = 0
                for gc in gcCodes {
                    if let monacoKey = shortcutsMapping[gc]?.0 {
                        key |= monacoKey
                    }
                }
                let command =
                    "editor.addCommand(\(String(key)), () => editor.trigger('', '\(entry.key)', null), '');"
                monacoWebView.evaluateJavaScript(command) { (result, error) in
                    if error != nil {
                        print("[Error] editor.addCommand: \(String(describing: error))")
                    }
                }
            }
        }
    }

    func makeCoordinator() -> MonacoEditor.Coordinator {
        Coordinator(self, env: App)
    }

    class Coordinator: NSObject, WKScriptMessageHandler,
        WKNavigationDelegate
    {

        struct action: Decodable, Identifiable {
            var id: String
            var label: String
        }

        struct marker: Decodable {
            let id = UUID()
            let endColumn: Int
            let endLineNumber: Int
            let startColumn: Int
            let startLineNumber: Int
            let severity: Int
            let message: String
            let owner: String
            let resource: resource
        }

        struct resource: Decodable {
            let path: String
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            control.App.stateManager.isMonacoEditorInitialized = false
            webView.reload()
        }

        func requestDiffUpdate(modelUri: String, force: Bool = false) {
            guard
                let sanitizedUri = URL(string: modelUri)?.standardizedFileURL.absoluteString
                    .removingPercentEncoding
            else {
                return
            }

            // If the cache hasn't been invalidated, it means the editor also have the up-to-date model.
            if let isCached = self.control.App.workSpaceStorage.gitServiceProvider?.isCached(
                url: sanitizedUri),
                !force, isCached
            {
                return
            }

            if let hasRepo = self.control.App.workSpaceStorage.gitServiceProvider?.hasRepository,
                hasRepo
            {
                self.control.App.workSpaceStorage.gitServiceProvider?.previous(
                    path: sanitizedUri, error: { err in print(err) },
                    completionHandler: { value in
                        DispatchQueue.main.async {
                            self.control.provideOriginalTextForUri(uri: modelUri, value: value)
                        }
                    })
            }
        }

        private func getAllActions() {
            let command = "editor.getActions().map((e) => {return {id: e.id, label: e.label}})"
            DispatchQueue.main.async {
                self.control.monacoWebView.evaluateJavaScript(command) { (result, error) in
                    guard error == nil, let result = result as? NSArray else {
                        return
                    }
                    do {
                        let jsonData = try JSONSerialization.data(
                            withJSONObject: result, options: [])
                        let decoded = try JSONDecoder().decode([action].self, from: jsonData)
                        self.control.App.editorShortcuts = decoded
                    } catch {
                        print(error)
                    }
                }
            }
        }

        func userContentController(
            _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            guard let result = message.body as? [String: AnyObject] else {
                return
            }
            guard let event = result["Event"] as? String else { return }

            switch event {
            case "focus":
                let notification = Notification(
                    name: Notification.Name("editor.focus"),
                    userInfo: ["sceneIdentifier": control.App.sceneIdentifier]
                )
                NotificationCenter.default.post(notification)
            case "Request Diff Update":
                if let modelUri = result["URI"] as? String {
                    requestDiffUpdate(modelUri: modelUri, force: true)
                }
            case "Crusor Position changed":
                let lineNumber = result["lineNumber"] as! Int
                let column = result["Column"] as! Int
                NotificationCenter.default.post(
                    name: Notification.Name("monaco.cursor.position.changed"), object: nil,
                    userInfo: [
                        "lineNumber": lineNumber, "column": column,
                        "sceneIdentifier": control.App.sceneIdentifier,
                    ])
            case "Content changed":
                let version = result["VersionID"] as! Int
                let content = result["currentContent"] as! String
                control.App.activeTextEditor?.currentVersionId = version
                control.App.activeTextEditor?.content = content

                let modelUri = result["URI"] as! String
                requestDiffUpdate(modelUri: modelUri)

                let startOffset = result["startOffset"] as! Int
                let endOffset = result["endOffset"] as! Int
                if control.editorSpellCheckEnabled && control.editorSpellCheckOnContentChanged {
                    control.checkSpelling(
                        text: content, uri: modelUri, startOffset: startOffset, endOffset: endOffset
                    )
                }
            case "Editor Initialising":
                // This is called when editor is being created, or switched to or from diff edtior
                control.monacoWebView.removeUIDropInteraction()
                control.applyUserOptions()
                control.applyCustomShortcuts()
                DispatchQueue.main.async {
                    self.control.App.loadURLQueue()
                }
                if globalDarkTheme != nil {
                    if let theJSONData = try? JSONSerialization.data(
                        withJSONObject: globalDarkTheme!, options: .prettyPrinted),
                        let jsonText = String(data: theJSONData, encoding: .utf8),
                        let name = globalDarkTheme!["name"] as? String,
                        let type = globalDarkTheme!["type"] as? String
                    {
                        control.setTheme(themeName: name, data: jsonText, isDark: type == "dark")
                    }

                }
                if globalLightTheme != nil {
                    if let theJSONData = try? JSONSerialization.data(
                        withJSONObject: globalLightTheme!, options: .prettyPrinted),
                        let jsonText = String(data: theJSONData, encoding: .utf8),
                        let name = globalLightTheme!["name"] as? String,
                        let type = globalLightTheme!["type"] as? String
                    {
                        control.setTheme(themeName: name, data: jsonText, isDark: type == "dark")
                    }
                }

                guard !control.App.stateManager.isMonacoEditorInitialized else { return }
                // TypeScript / JavaScript Types
                control.injectTypes(
                    url: Bundle.main.url(forResource: "npm", withExtension: "bundle")!
                        .appendingPathComponent("node_modules/@types"))
                control.App.scanForTypes()

                control.App.textEditors.forEach {
                    control.newModel(url: $0.url.absoluteString, content: $0.content)
                }
                if let activeURL = control.App.activeTextEditor?.url {
                    control.setModel(url: activeURL.absoluteString)
                }
                if control.stateRestorationEnabled,
                    let activeEditorMonacoState = control.activeEditorMonacoState
                {
                    control.executeJavascript(
                        command: "editor.restoreViewState(\(activeEditorMonacoState))")
                }
                getAllActions()
                control.App.stateManager.isMonacoEditorInitialized = true
            case "Markers updated":
                let markers = result["Markers"] as! [Any]
                control.App.problems = [:]
                for mkr in markers {
                    let jsonData = try! JSONSerialization.data(withJSONObject: mkr, options: [])
                    let decoded = try! JSONDecoder().decode(marker.self, from: jsonData)
                    if let url = URL(
                        string: String(
                            decoded.resource.path.dropFirst().replacingOccurrences(
                                of: " ", with: "%20")))
                    {
                        if control.App.problems[url] != nil {
                            control.App.problems[url]!.append(decoded)
                        } else {
                            control.App.problems[url] = [decoded]
                        }
                    }
                }
            case "Open URL":
                let urlString = result["url"] as! String
                if let url = URL(string: urlString) {
                    if url.scheme == "http" || url.scheme == "https" {
                        control.App.safariManager.showSafari(url: url)

                    }
                }

            default:
                print("[Error] \(event) not handled")
            }
        }

        @objc func handleToolbarChanges(notification: Notification) {
            if let key = notification.userInfo?["enabled"] as? Bool {
                if key {
                    injectBarButtons()
                } else {
                    control.monacoWebView.addInputAccessoryView(toolbar: UIView.init())
                }
            }
        }

        @objc func injectBarButtons() {
            let toolbar = UIHostingController(
                rootView: EditorKeyboardToolBar().environmentObject(env))
            toolbar.view.frame = CGRect(
                x: 0, y: 0, width: (control.monacoWebView.bounds.width), height: 40)

            control.monacoWebView.addInputAccessoryView(toolbar: toolbar.view)
        }

        var control: MonacoEditor
        var env: MainApp

        init(_ control: MonacoEditor, env: MainApp) {
            self.control = control
            self.env = env
            super.init()
        }
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard App.stateManager.isMonacoEditorInitialized else { return }
        guard let activeTextEditor = App.activeTextEditor else {
            Task {
                try await setModelToEmpty()
            }
            return
        }
        if let diffEditor = activeTextEditor as? DiffTextEditorInstnace {
            let diffURL = URL(string: "git://" + diffEditor.url.path)!
            switchToDiffView(
                originalContent: diffEditor.compareWith,
                modifiedContent: diffEditor.content,
                url: diffURL.absoluteString,
                url2: diffEditor.url.absoluteString
            )
        } else {
            Task {
                if await isEditorInDiffMode() {
                    switchToNormView()
                }
                try await onRequestNewTextModel(
                    url: activeTextEditor.url, value: activeTextEditor.content)
            }
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        monacoWebView.isOpaque = false
        monacoWebView.scrollView.bounces = false
        monacoWebView.customUserAgent =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15) AppleWebKit/605.1.15 (KHTML, like Gecko) CodeApp"
        monacoWebView.contentMode = .scaleToFill
        monacoWebView.navigationDelegate = context.coordinator

        if !monacoWebView.isMessageHandlerAdded {
            let contentManager = monacoWebView.configuration.userContentController
            contentManager.add(context.coordinator, name: "toggleMessageHandler")
            monacoWebView.isMessageHandlerAdded = true
        }

        if toolBarEnabled {
            context.coordinator.injectBarButtons()
        } else {
            monacoWebView.addInputAccessoryView(toolbar: UIView.init())
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(context.coordinator.handleToolbarChanges(notification:)),
            name: Notification.Name("toolbarSettingChanged"), object: nil)

        return monacoWebView
    }
}

extension WKWebView {
    @MainActor
    @discardableResult
    func evaluateJavaScriptAsync(_ str: String) async throws -> Any? {
        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Any?, Error>) in
            DispatchQueue.main.async {
                self.evaluateJavaScript(str) { data, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: data)
                    }
                }
            }
        }
    }
}

extension MonacoEditor {
    enum Failure: Error {
        case failedToEncodeDataAsBase64
    }
}

extension MonacoEditor {
    func isEditorInDiffMode() async -> Bool {
        let result = try? await monacoWebView.evaluateJavaScriptAsync(
            "editor.getEditorType() !== 'vs.editor.ICodeEditor'")
        return (result as? Bool) ?? false
    }

    func isEditorInFocus() async -> Bool {
        let result = try? await monacoWebView.evaluateJavaScriptAsync(
            "document.activeElement.tagName == 'TEXTAREA'")
        return (result as? Bool) ?? false
    }

    func onRequestNewTextModel(url: URL, value: String) async throws {
        guard let encodedContent = value.base64Encoded(),
            let encodedUrl = url.absoluteString.base64Encoded()
        else {
            throw MonacoEditor.Failure.failedToEncodeDataAsBase64
        }
        try await monacoWebView.evaluateJavaScriptAsync(
            "onRequestNewTextModel('\(encodedUrl)', '\(encodedContent)')"
        )
    }

    func setModel(url: URL) async throws {
        guard let encodedUrl = url.absoluteString.base64Encoded() else {
            throw MonacoEditor.Failure.failedToEncodeDataAsBase64
        }
        try await monacoWebView.evaluateJavaScriptAsync("setModel('\(encodedUrl)');")
    }

    func setModelToEmpty() async throws {
        try await monacoWebView.evaluateJavaScriptAsync("editor.setModel()")
    }

    @MainActor
    func setValueForModel(url: URL, value: String) async throws {
        guard let encodedContent = value.base64Encoded(),
            let encodedUrl = url.absoluteString.base64Encoded()
        else {
            throw MonacoEditor.Failure.failedToEncodeDataAsBase64
        }
        try await monacoWebView.evaluateJavaScriptAsync(
            "setValueForModel('\(encodedUrl)', '\(encodedContent)')"
        )
    }

    func blur() async throws {
        try await monacoWebView.evaluateJavaScriptAsync(
            "document.getElementById('overlay').focus()")
    }
}
