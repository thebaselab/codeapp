//
//  EditorImplementation.swift
//  Code
//
//  Created by Ken Chung on 01/02/2024.
//

import Foundation

struct EditorOptions: Codable {
    var fontSize: Int
    var fontFamily: String
    var fontLigaturesEnabled: Bool
    var tabRenderSize: Int
    var readOnly: Bool
    var autoClosingBrackets: Bool
    var miniMapEnabled: Bool
    var lineNumbersEnabled: Bool
    var _smoothScrollingEnabled: Bool
    var wordWrap: WordWrapOption
    var renderWhiteSpaces: RenderWhiteSpaceMode
    var toolBarEnabled: Bool
    var vimEnabled: Bool

    init() {
        self.fontSize = 14
        self.fontFamily = "Menlo"
        self.fontLigaturesEnabled = false
        self.tabRenderSize = 4
        self.readOnly = false
        self.autoClosingBrackets = true
        self.miniMapEnabled = true
        self.lineNumbersEnabled = true
        self._smoothScrollingEnabled = false
        self.wordWrap = .off
        self.renderWhiteSpaces = .selection
        self.toolBarEnabled = true
        self.vimEnabled = false
    }
}

enum WordWrapOption: Codable, CaseIterable {
    case off, on, wordWrapColumn, bounded
}

enum RenderWhiteSpaceMode: Codable, CaseIterable {
    case none, boundary, selection, trailing, all
}

enum CursorDirection {
    case left, right, up, down
}

struct MonacoEditorAction: Decodable, Identifiable {
    var id: String
    var label: String
}

struct MonacoEditorMarker: Decodable, Identifiable {
    let id = UUID()
    var endColumn: Int
    var endLineNumber: Int
    var startColumn: Int
    var startLineNumber: Int
    var severity: Int
    var message: String
    var owner: String
    var resource: MonacoResource
}

struct MonacoResource: Decodable {
    var path: String
}

protocol EditorImplementationDelegate: AnyObject {
    func didEnterFocus()
    func didFinishInitialising()
    func editorImplementation(requestTextForDiffForModelURL url: String, ignoreCache: Bool)
        async -> String?
    func editorImplementation(
        contentDidChangeForModelURL url: String, content: String, versionID: Int)
    func editorImplementation(cursorPositionDidChange line: Int, column: Int)
    func editorImplementation(onOpenURL url: String)

    // Monaco specfic methods
    func editorImplementation(markersDidUpdate markers: [MonacoEditorMarker])
    func editorImplementation(vimModeEvent id: String, userInfo: [String: Any])
}

struct EditorTheme {
    var dark: Theme?
    var light: Theme?
}

// A web-based editor implemenation
protocol EditorImplementation: AnyObject {
    var webView: WebViewBase { get }
    var options: EditorOptions { get set }
    var theme: EditorTheme { get set }
    var delegate: EditorImplementationDelegate? { get set }

    // Text models
    func setModel(url: String) async
    func setModelToEmpty() async
    func createNewModel(url: String, value: String) async
    func renameModel(oldURL: String, updatedURL: String) async
    func setValueForModel(url: String, value: String) async
    func removeAllModels() async

    // State Restoration
    func getViewState() async -> String

    // Editor operations
    func setVSTheme(theme: Theme) async
    func focus() async
    func blur() async
    func searchTermInEditor(term: String) async
    func scrollToLine(line: Int) async
    func openSearchWidget() async
    func undo() async
    func redo() async
    func getSelectedValue() async -> String
    func pasteText(text: String) async
    func insertTextAtCurrentCursor(text: String) async
    func moveCursor(direction: CursorDirection) async
    func editorInFocus() async -> Bool

    // Git operations
    func invalidateDecorations() async
    func switchToDiffMode(
        originalContent: String, modifiedContent: String, originalUrl: String, modifiedUrl: String)
        async
    func switchToInlineDiffView() async
    func switchToNormalMode() async
    func moveToNextDiff() async
    func moveToPreviousDiff() async
    func isEditorInDiffMode() async -> Bool

    // Monaco Editor operations
    func _applyCustomShortcuts() async
    func _toggleCommandPalatte() async
    func _toggleGoToLineWidget() async
    func _restoreEditorState(state: String) async
    func _getMonacoActions() async -> [MonacoEditorAction]
}
