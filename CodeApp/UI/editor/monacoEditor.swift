//
//  monacoEditor.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import GameController
import SwiftUI
import WebKit

var isEditorInited = false
private var ToolbarHandle: UInt8 = 0
let monacoWebView = WebViewBase()

class WebViewBase: KBWebViewBase {

    init() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.preferences.setValue(true, forKey: "shouldAllowUserInstalledFonts")
        super.init(frame: .zero, configuration: config)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var candidateView: UIView? {
        var candidateView: UIView? = nil
        for view in self.scrollView.subviews {
            if String(describing: type(of: view)).hasPrefix("WKContent") {
                candidateView = view
            }
        }
        return candidateView
    }

    func addInputAccessoryView(toolbar: UIView?) {
        guard let toolbar = toolbar else { return }
        guard let targetView = candidateView else { return }

        objc_setAssociatedObject(
            self, &ToolbarHandle, toolbar, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let newClass: AnyClass? = classWithCustomAccessoryView(targetView: targetView)
        object_setClass(targetView, newClass!)
    }

    func removeUIDropInteraction() {
        func findInteractionView(in subviews: [UIView]) -> UIView? {
            for subview in subviews {
                for interaction in subview.interactions {
                    if interaction is UIDragInteraction {
                        return subview
                    }
                }
                return findInteractionView(in: subview.subviews)
            }
            return nil
        }

        if let interactionView = findInteractionView(in: subviews) {
            for interaction in interactionView.interactions {
                if interaction is UIDragInteraction || interaction is UIDropInteraction {
                    interactionView.removeInteraction(interaction)
                }
            }
        }
    }

    private func classWithCustomAccessoryView(targetView: UIView) -> AnyClass? {
        guard let targetSuperClass = targetView.superclass else { return nil }
        let customInputAccessoryViewClassName = "\(targetSuperClass)_CustomInputAccessoryView"

        var newClass: AnyClass? = NSClassFromString(customInputAccessoryViewClassName)
        if newClass == nil {
            newClass = objc_allocateClassPair(
                object_getClass(targetView), customInputAccessoryViewClassName, 0)
        } else {
            return newClass
        }

        let newMethod = class_getInstanceMethod(
            WebViewBase.self, #selector(WebViewBase.getCustomInputAccessoryView))
        class_addMethod(
            newClass.self, #selector(getter:UIResponder.inputAccessoryView),
            method_getImplementation(newMethod!), method_getTypeEncoding(newMethod!))

        objc_registerClassPair(newClass!)

        return newClass
    }

    @objc func getCustomInputAccessoryView() -> UIView? {
        var superWebView: UIView? = self
        while (superWebView != nil) && !(superWebView is WKWebView) {
            superWebView = superWebView?.superview
        }
        let customInputAccessory = objc_getAssociatedObject(superWebView as Any, &ToolbarHandle)
        superWebView?.inputAssistantItem.leadingBarButtonGroups = []
        superWebView?.inputAssistantItem.trailingBarButtonGroups = []
        return customInputAccessory as? UIView
    }

    override open var inputAccessoryView: UIView? {
        // remove/replace the default accessory view
        return nil
    }
}

struct monacoEditor: UIViewRepresentable {

    @EnvironmentObject var status: MainApp

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @AppStorage("editorFontSize") var fontSize: Int = 14
    @AppStorage("editorFontFamily") var fontFamily: String = "Menlo"
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

    private var contentView: UIView?

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
            command: "editor.updateOptions({fontFamily: \"\(fontFamily)\", fontLigatures: true})")

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

    func setCurrentModelValue(value: String) {
        let encoded = value.base64Encoded()!
        self.executeJavascript(
            command: "var decodedCommand = decodeURIComponent(escape(window.atob('\(encoded)')))")
        self.executeJavascript(command: "editor.getModel().setValue(decodedCommand)")
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
            SpellChecker.shared.check(text: content, uri: url)
        }
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

        var themeName = themeName

        for keyword in "() " {
            themeName = themeName.replacingOccurrences(of: String(keyword), with: "")
        }

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

    func updateUIView(_ uiView: WKWebView, context: Context) {
        return
    }

    func makeCoordinator() -> monacoEditor.Coordinator {
        Coordinator(self, env: status)
    }

    class Coordinator: NSObject, WKScriptMessageHandler, UIGestureRecognizerDelegate {

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

        func requestDiffUpdate(modelUri: String, force: Bool = false) {
            guard
                let sanitizedUri = URL(string: modelUri)?.standardizedFileURL.absoluteString
                    .removingPercentEncoding
            else {
                return
            }

            // If the cache hasn't been invalidated, it means the editor also have the up-to-date model.
            if let isCached = self.control.status.workSpaceStorage.gitServiceProvider?.isCached(
                url: sanitizedUri),
                !force, isCached
            {
                return
            }

            if let hasRepo = self.control.status.workSpaceStorage.gitServiceProvider?.hasRepository,
                hasRepo
            {
                DispatchQueue.global(qos: .utility).async {
                    self.control.status.workSpaceStorage.gitServiceProvider?.previous(
                        path: sanitizedUri, error: { err in print(err) },
                        completionHandler: { value in
                            DispatchQueue.main.async {
                                self.control.provideOriginalTextForUri(uri: modelUri, value: value)
                            }
                        })
                }
            }
        }

        private func getAllActions() {
            let command = "editor.getActions().map((e) => {return {id: e.id, label: e.label}})"
            DispatchQueue.main.async {
                monacoWebView.evaluateJavaScript(command) { (result, error) in
                    guard error == nil, let result = result as? NSArray else {
                        return
                    }
                    do {
                        let jsonData = try JSONSerialization.data(
                            withJSONObject: result, options: [])
                        let decoded = try JSONDecoder().decode([action].self, from: jsonData)
                        self.control.status.editorShortcuts = decoded
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
            case "Request Diff Update":
                if let modelUri = result["URI"] as? String {
                    requestDiffUpdate(modelUri: modelUri, force: true)
                }
            case "Crusor Position changed":
                let lineNumber = result["lineNumber"] as! Int
                let column = result["Column"] as! Int
                NotificationCenter.default.post(
                    name: Notification.Name("monaco.cursor.position.changed"), object: nil,
                    userInfo: ["lineNumber": lineNumber, "column": column])
            case "Content changed":
                let version = result["VersionID"] as! Int
                let content = result["currentContent"] as! String
                if (control.status.activeEditor?.lastSavedVersionId
                    == control.status.activeEditor?.currentVersionId  // Saved -> Unsaved
                    && version != control.status.activeEditor?.lastSavedVersionId)
                    || (control.status.activeEditor?.lastSavedVersionId
                        != control.status.activeEditor?.currentVersionId  // Unsaved -> Saved
                        && version == control.status.activeEditor?.lastSavedVersionId)
                {
                    NotificationCenter.default.post(
                        name: Notification.Name("monaco.editor.currentContent.changed"),
                        object: nil, userInfo: nil)
                }
                control.status.activeEditor?.currentVersionId = version
                control.status.activeEditor?.content = content

                let modelUri = result["URI"] as! String
                requestDiffUpdate(modelUri: modelUri)

                let startOffset = result["startOffset"] as! Int
                let endOffset = result["endOffset"] as! Int
                if control.editorSpellCheckEnabled && control.editorSpellCheckOnContentChanged {
                    SpellChecker.shared.check(
                        text: content, uri: modelUri, startOffset: startOffset, endOffset: endOffset
                    )
                }
            case "Editor Initialising":
                isEditorInited = true
                monacoWebView.removeUIDropInteraction()
                control.applyUserOptions()
                control.status.loadURLQueue()
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
                // TypeScript / JavaScript Types
                control.injectTypes(
                    url: Bundle.main.url(forResource: "npm", withExtension: "bundle")!
                        .appendingPathComponent("node_modules/@types"))
                control.status.scanForTypes()

                for editor in control.status.editors {
                    control.newModel(url: editor.url, content: editor.content)
                }
                if !control.status.editors.isEmpty {
                    control.setModel(url: control.status.currentURL())
                }
                if let state = UserDefaults.standard.string(forKey: "uistate.activeEditor.state") {
                    control.executeJavascript(command: "editor.restoreViewState(\(state))")
                }
                UserDefaults.standard.setValue(true, forKey: "uistate.restoredSuccessfully")
                control.applyCustomShortcuts()
                getAllActions()
            case "Markers updated":
                let markers = result["Markers"] as! [Any]
                control.status.problems = [:]
                for mkr in markers {
                    let jsonData = try! JSONSerialization.data(withJSONObject: mkr, options: [])
                    let decoded = try! JSONDecoder().decode(marker.self, from: jsonData)
                    if let url = URL(
                        string: String(
                            decoded.resource.path.dropFirst().replacingOccurrences(
                                of: " ", with: "%20")))
                    {
                        if control.status.problems[url] != nil {
                            control.status.problems[url]!.append(decoded)
                        } else {
                            control.status.problems[url] = [decoded]
                        }
                    }
                }
            default:
                print("[Error] \(event) not handled")
            }
        }

        var offsetY: CGFloat = 0.0
        var offsetX: CGFloat = 0.0

        @objc func panColor(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let editor = control.status.activeEditor else {
                return
            }
            let velocity = gestureRecognizer.velocity(in: monacoWebView)
            if editor.type == .file {
                control.executeJavascript(
                    command:
                        "editor.setScrollPosition({scrollTop: editor.getScrollTop() + (-1 * \(velocity.y / 100))}, 0)"
                )
                control.executeJavascript(
                    command:
                        "editor.setScrollPosition({scrollLeft: editor.getScrollLeft() + (-1 * \(velocity.x / 100))}, 0)"
                )
            } else if editor.type == .diff {
                control.executeJavascript(
                    command:
                        "editor.getOriginalEditor().setScrollPosition({scrollTop: editor.getOriginalEditor().getScrollTop() + (-1 * \(velocity.y / 100))}, 0)"
                )
                control.executeJavascript(
                    command:
                        "editor.getOriginalEditor().setScrollPosition({scrollLeft: editor.getOriginalEditor().getScrollLeft() + (-1 * \(velocity.x / 100))}, 0)"
                )
            }
            offsetY = velocity.y
            offsetX = velocity.x
            if gestureRecognizer.state == .ended {
                offsetY = 0.0
                offsetX = 0.0
            }
        }

        @objc func mousePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let editor = control.status.activeEditor else {
                return
            }
            let translation = gestureRecognizer.translation(in: monacoWebView)
            if editor.type == .file {
                control.executeJavascript(
                    command:
                        "editor.setScrollPosition({scrollTop: editor.getScrollTop() + (-1 * \(translation.y - offsetY))}, 0)"
                )
                control.executeJavascript(
                    command:
                        "editor.setScrollPosition({scrollLeft: editor.getScrollLeft() + (-1 * \(translation.x - offsetX))}, 0)"
                )
            } else if editor.type == .diff {
                control.executeJavascript(
                    command:
                        "editor.getOriginalEditor().setScrollPosition({scrollTop: editor.getOriginalEditor().getScrollTop() + (-1 * \(translation.y - offsetY))}, 0)"
                )
                control.executeJavascript(
                    command:
                        "editor.getOriginalEditor().setScrollPosition({scrollLeft: editor.getOriginalEditor().getScrollLeft() + (-1 * \(translation.x - offsetX))}, 0)"
                )
            }

            offsetY = translation.y
            offsetX = translation.x
            if gestureRecognizer.state == .ended {
                offsetY = 0.0
                offsetX = 0.0
            }
        }

        @objc func handleToolbarChanges(notification: Notification) {
            if let key = notification.userInfo?["enabled"] as? Bool {
                if key {
                    injectBarButtons()
                } else {
                    monacoWebView.addInputAccessoryView(toolbar: UIView.init())
                }
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch
        ) -> Bool {
            return false
        }

        @objc func injectBarButtons() {
            let toolbar = UIHostingController(rootView: keyboardToolBar().environmentObject(env))
            toolbar.view.frame = CGRect(x: 0, y: 0, width: (monacoWebView.bounds.width), height: 40)

            monacoWebView.addInputAccessoryView(toolbar: toolbar.view)
        }

        var control: monacoEditor
        var env: MainApp

        init(_ control: monacoEditor, env: MainApp) {
            self.control = control
            self.env = env
            super.init()
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        monacoWebView.isOpaque = false
        monacoWebView.scrollView.bounces = false
        monacoWebView.customUserAgent =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15) AppleWebKit/605.1.15 (KHTML, like Gecko) CodeApp"
        monacoWebView.contentMode = .scaleToFill

        if !isEditorInited {
            let contentManager = monacoWebView.configuration.userContentController
            contentManager.add(context.coordinator, name: "toggleMessageHandler")
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
