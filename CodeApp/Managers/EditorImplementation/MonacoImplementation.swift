//
//  MonacoImplementation.swift
//  Code
//
//  Created by Ken Chung on 01/02/2024.
//

import Foundation
import GameController
import SwiftUI

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

class MonacoImplementation: NSObject {
    private var monacoWebView = WebViewBase()
    var options: EditorOptions {
        didSet {
            Task { await configureCustomOptions() }
        }
    }
    var theme: EditorTheme {
        didSet {
            Task { await configureTheme() }
        }
    }
    weak var delegate: EditorImplementationDelegate?

    init(options: EditorOptions, theme: EditorTheme) {
        self.options = options
        self.theme = theme
        super.init()

        monacoWebView.isOpaque = false
        monacoWebView.scrollView.bounces = false
        monacoWebView.customUserAgent =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15) AppleWebKit/605.1.15 (KHTML, like Gecko) CodeApp"
        monacoWebView.contentMode = .scaleToFill

        if !monacoWebView.isMessageHandlerAdded {
            let contentManager = monacoWebView.configuration.userContentController
            contentManager.add(self, name: "toggleMessageHandler")
            monacoWebView.isMessageHandlerAdded = true
        }

        let monacoPath = Bundle.main.path(forResource: "monaco-textmate", ofType: "bundle")
        monacoWebView.loadFileURL(
            URL(fileURLWithPath: monacoPath!).appendingPathComponent("index.html"),
            allowingReadAccessTo: URL(fileURLWithPath: monacoPath!))
    }

    private func setupEditor() async {
        await monacoWebView.removeUIDropInteraction()
        await configureCustomOptions()
        await configureTheme()

        // Built-in Node.js types
        await injectTypes(
            url: Bundle.main.url(forResource: "npm", withExtension: "bundle")!
                .appendingPathComponent("node_modules/@types"))
    }

    private func configureTheme() async {
        if let dark = theme.dark {
            await setVSTheme(theme: dark)
        }
        if let light = theme.light {
            await setVSTheme(theme: light)
        }
    }

    private func configureCustomOptions() async {
        await applyOptions(options: "automaticLayout: true, lineNumbersMinChars: 5")
        await applyOptions(options: "fontSize: \(String(options.fontSize))")
        await applyFont(fontFamily: options.fontFamily)
        await applyOptions(options: "autoClosingBrackets: \(options.autoClosingBrackets)")
        await applyOptions(options: "minimap: {enabled: \(options.miniMapEnabled)}")
        await applyOptions(options: "lineNumbers: \(options.lineNumbersEnabled)")
        await applyOptions(options: "smoothScrolling: \(options._smoothScrollingEnabled)")
        await applyOptions(options: "readOnly: \(options.readOnly)")
        await applyOptions(options: "tabSize: \(String(options.tabRenderSize))")
        await applyOptions(options: "renderWhitespace: '\(options.renderWhiteSpaces)'")
        await applyOptions(options: "wordWrap: '\(options.wordWrap)'")
        _ = try? await monacoWebView.evaluateJavaScriptAsync("toggleVimMode(\(options.vimEnabled))")
        await MainActor.run {
            if options.toolBarEnabled {
                let toolbar = UIHostingController(
                    rootView: EditorKeyboardToolBar(editorImplementation: self))
                toolbar.view.frame = CGRect(
                    x: 0, y: 0, width: (monacoWebView.bounds.width), height: 40)
                monacoWebView.addInputAccessoryView(toolbar: toolbar.view)
            } else {
                monacoWebView.removeInputAccessoryView()
            }
        }
    }

    private func applyOptions(options: String) async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync("editor.updateOptions({\(options)})")
    }

    private func provideOriginalTextForUri(uri: String, value: String) async {
        guard let encoded = value.base64Encoded() else {
            return
        }
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "provideOriginalTextForUri(`\(uri)`, `\(encoded)`)")
    }

    private func applyFont(fontFamily: String) async {
        guard
            let percentEncoded = fontFamily.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed)
        else {
            return
        }
        let js = """
            var styles = `
                @font-face {
                font-family: "\(fontFamily)";
                src: local("\(fontFamily)"),
                  url("fonts://\(percentEncoded).ttf") format("truetype");
              }
            `
            var styleSheet = document.createElement("style")
            styleSheet.innerHTML = styles
            document.head.appendChild(styleSheet)
            """
        _ = try? await monacoWebView.evaluateJavaScriptAsync(js)
        await applyOptions(options: "fontFamily: \"\(fontFamily)\"")
    }

    private func injectTypes(url: URL) async {
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
            _ = try? await monacoWebView.evaluateJavaScriptAsync(
                "monaco.languages.typescript.javascriptDefaults.addExtraLib(decodeURIComponent(escape(window.atob('\(encodedContent)'))),'\(path)')"
            )
            _ = try? await monacoWebView.evaluateJavaScriptAsync(
                "monaco.languages.typescript.typescriptDefaults.addExtraLib(decodeURIComponent(escape(window.atob('\(encodedContent)'))),'\(path)')"
            )
        }
    }
}

extension MonacoImplementation: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        guard let result = message.body as? [String: AnyObject],
            let event = result["Event"] as? String
        else {
            return
        }

        switch event {
        case "focus":
            delegate?.didEnterFocus()
        case "Request Diff Update":
            guard let modelUri = result["URI"] as? String else { return }
            Task {
                if let updatedText = await delegate?.editorImplementation(
                    requestTextForDiffForModelURL: modelUri, ignoreCache: true)
                {
                    await provideOriginalTextForUri(uri: modelUri, value: updatedText)
                }
            }
        case "Crusor Position changed":
            let lineNumber = result["lineNumber"] as! Int
            let column = result["Column"] as! Int
            delegate?.editorImplementation(cursorPositionDidChange: lineNumber, column: column)
        case "Content changed":
            let version = result["VersionID"] as! Int
            let content = result["currentContent"] as! String
            let modelUri = result["URI"] as! String
            delegate?.editorImplementation(
                contentDidChangeForModelURL: modelUri, content: content, versionID: version)
            Task {
                if let updatedText = await delegate?.editorImplementation(
                    requestTextForDiffForModelURL: modelUri, ignoreCache: false)
                {
                    await provideOriginalTextForUri(uri: modelUri, value: updatedText)
                }
            }
        case "Editor Initialising":
            Task { @MainActor in
                await setupEditor()
                delegate?.didFinishInitialising()
            }
        case "Markers updated":
            guard let markers = result["Markers"] as? [Any] else { return }
            let monacoMarkers = markers.map {
                let jsonData = try! JSONSerialization.data(withJSONObject: $0, options: [])
                return try! JSONDecoder().decode(MonacoEditorMarker.self, from: jsonData)
            }
            delegate?.editorImplementation(markersDidUpdate: monacoMarkers)
        case "Open URL":
            let urlString = result["url"] as! String
            delegate?.editorImplementation(onOpenURL: urlString)
        case "vim.mode.change", "vim.keybuffer.set", "vim.visible.set", "vim.close.input",
            "vim.claer":
            delegate?.editorImplementation(vimModeEvent: event, userInfo: result)
        default:
            print("[MonacoImplementation]: Event '\(event)' not handled.")
        }
    }
}

extension MonacoImplementation: EditorImplementation {
    var view: UIView {
        monacoWebView
    }

    func setModel(url: String) async {
        guard let encodedUrl = url.base64Encoded() else {
            return
        }
        _ = try? await monacoWebView.evaluateJavaScriptAsync("setModel('\(encodedUrl)');")
    }

    func setModelToEmpty() async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync("editor.setModel()")
    }

    func createNewModel(url: String, value: String) async {
        guard let encodedContent = value.base64Encoded(),
            let encodedUrl = url.base64Encoded()
        else {
            return
        }
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "onRequestNewTextModel('\(encodedUrl)', '\(encodedContent)')"
        )
    }

    func renameModel(oldURL: String, updatedURL: String) async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "renameModel(`\(oldURL)`,`\(updatedURL)`)"
        )
    }

    func setValueForModel(url: String, value: String) async {
        guard let encodedContent = value.base64Encoded(),
            let encodedUrl = url.base64Encoded()
        else {
            return
        }
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "setValueForModel('\(encodedUrl)', '\(encodedContent)')"
        )
    }

    func removeAllModels() async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "monaco.editor.getModels().forEach(model => model.dispose());"
        )
    }

    func getViewState() async -> String {
        return
            (try? await monacoWebView.evaluateJavaScriptAsync(
                "JSON.stringify(editor.saveViewState())"
            )) as? String ?? "{}"
    }

    func setVSTheme(theme: Theme) async {
        var theme = theme
        let themeName = theme.name.replacingOccurrences(of: " ", with: "").replacingOccurrences(
            of: "[^A-Za-z0-9]+", with: "", options: [.regularExpression])
        if let base64 = theme.jsonString.base64Encoded() {
            _ = try? await monacoWebView.evaluateJavaScriptAsync(
                "applyBase64AsTheme('\(base64)', '\(themeName)', \(theme.isDark))")
        }
    }

    func focus() async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync("editor.focus()")
    }

    func blur() async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "document.getElementById('overlay').focus()")
    }

    func searchTermInEditor(term: String) async {
        guard let encoded = term.base64Encoded() else {
            return
        }
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "var decodedCommand = decodeURIComponent(escape(window.atob('\(encoded)')))")
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "var range = editor.getModel().findMatches(decodedCommand)[0].range")
        _ = try? await monacoWebView.evaluateJavaScriptAsync("editor.setSelection(range)")
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "editor.getAction('actions.find').run()")
    }

    func scrollToLine(line: Int) async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync("editor.revealLine(\(String(line)));")
    }

    func openSearchWidget() async {
        await focus()
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "editor.getAction('actions.find').run()")
    }

    func undo() async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync("editor.getModel().undo()")
    }

    func redo() async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync("editor.getModel().redo()")
    }

    func getSelectedValue() async -> String {
        return
            (try? await monacoWebView.evaluateJavaScriptAsync(
                "editor.getModel().getValueInRange(editor.getSelection())")) as? String ?? ""
    }

    func pasteText(text: String) async {
        guard let encoded = text.base64Encoded() else { return }
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "editor.executeEdits('source',[{identifier: {major: 1, minor: 1}, range: editor.getSelection(), text: decodeURIComponent(escape(window.atob('\(encoded)'))), forceMoveMarkers: true}])"
        )
    }

    func insertTextAtCurrentCursor(text: String) async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "editor.trigger('keyboard', 'type', {text: decodeURIComponent(escape(window.atob('\(text)')))})"
        )
    }

    func moveCursor(direction: CursorDirection) async {
        switch direction {
        case .left:
            _ = try? await monacoWebView.evaluateJavaScriptAsync(
                "editor.setPosition({lineNumber: editor.getPosition().lineNumber, column: editor.getPosition().column - 1})"
            )
        case .right:
            _ = try? await monacoWebView.evaluateJavaScriptAsync(
                "editor.setPosition({lineNumber: editor.getPosition().lineNumber, column: editor.getPosition().column + 1})"
            )
        case .up:
            _ = try? await monacoWebView.evaluateJavaScriptAsync(
                "editor.setPosition({lineNumber: editor.getPosition().lineNumber - 1, column: editor.getPosition().column})"
            )
        case .down:
            _ = try? await monacoWebView.evaluateJavaScriptAsync(
                "editor.setPosition({lineNumber: editor.getPosition().lineNumber + 1, column: editor.getPosition().column})"
            )
        }
    }

    func editorInFocus() async -> Bool {
        return
            (try? await monacoWebView.evaluateJavaScriptAsync(
                "document.activeElement.tagName == 'TEXTAREA'")) as? Bool ?? false
    }

    func invalidateDecorations() async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync("invalidateDecorations()")
    }

    func switchToDiffMode(
        originalContent: String, modifiedContent: String, originalUrl: String, modifiedUrl: String
    ) async {
        guard let original = originalContent.base64Encoded(),
            let modified = modifiedContent.base64Encoded()
        else {
            return
        }
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "switchToDiffView('\(original)','\(modified)','\(originalUrl)','\(modifiedUrl)')")
    }

    func switchToInlineDiffView() async {
        await applyOptions(options: "renderSideBySide: false")
    }

    func switchToNormalMode() async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync("switchToNormalView()")
    }

    func moveToNextDiff() async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync("navi.next()")
    }

    func moveToPreviousDiff() async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync("navi.previous()")
    }

    func isEditorInDiffMode() async -> Bool {
        let result = try? await monacoWebView.evaluateJavaScriptAsync(
            "editor.getEditorType() !== 'vs.editor.ICodeEditor'")
        return (result as? Bool) ?? false
    }

    func _applyCustomShortcuts() async {
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
                _ = try? await monacoWebView.evaluateJavaScriptAsync(command)
            }
        }
    }

    func _toggleCommandPalatte() async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "editor.trigger('', 'editor.action.quickCommand')")
    }

    func _toggleGoToLineWidget() async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "editor.focus();editor.trigger('', 'editor.action.gotoLine')")
    }

    func _restoreEditorState(state: String) async {
        _ = try? await monacoWebView.evaluateJavaScriptAsync(
            "editor.restoreViewState(\(state))")
    }

    func _getMonacoActions() async -> [MonacoEditorAction] {
        let script = "editor.getActions().map((e) => {return {id: e.id, label: e.label}})"
        do {
            guard let result = (try await monacoWebView.evaluateJavaScriptAsync(script)) as? NSArray
            else {
                return []
            }
            let jsonData = try JSONSerialization.data(
                withJSONObject: result, options: [])
            return try JSONDecoder().decode([MonacoEditorAction].self, from: jsonData)
        } catch {
            return []
        }
    }
}
