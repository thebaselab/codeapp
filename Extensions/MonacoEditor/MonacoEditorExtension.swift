//
//  MonacoEditorExtension.swift
//  Code
//
//  Created by Ken Chung on 15/8/2023.
//

import SwiftUI

private let MONACO_EDITOR_EXTENSION_ID = "MONACO_EDITOR_AUX"

class MonacoEditorAuxiliaryExtension: CodeAppExtension {
    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {
        let encodingStatusBarItem = StatusBarItem(
            extensionID: MONACO_EDITOR_EXTENSION_ID,
            view: AnyView(EncodingMenu()),
            shouldDisplay: { app.activeEditor is TextEditorInstance },
            positionPreference: .right,
            positionPrecedence: Int.max
        )
        let lineColumnIndicatorStatusBarItem = StatusBarItem(
            extensionID: MONACO_EDITOR_EXTENSION_ID,
            view: AnyView(EditorLineColumnIndicator()),
            shouldDisplay: { app.activeEditor is TextEditorInstance },
            positionPreference: .right,
            positionPrecedence: Int.max - 1
        )
        let readOnlyStatusBarItem = StatusBarItem(
            extensionID: MONACO_EDITOR_EXTENSION_ID,
            view: AnyView(Text("READ-ONLY")),
            shouldDisplay: { app.editorOptions.value.readOnly },
            positionPreference: .left,
            positionPrecedence: Int.max
        )
        let vimKeyBufferStatusBarItem = StatusBarItem(
            extensionID: MONACO_EDITOR_EXTENSION_ID,
            view: AnyView(VimKeyBufferLabel()),
            shouldDisplay: { app.activeEditor is TextEditorInstance },
            positionPreference: .right,
            positionPrecedence: Int.min
        )
        let vimModeStatusBarItem = StatusBarItem(
            extensionID: MONACO_EDITOR_EXTENSION_ID,
            view: AnyView(VimModeLabel()),
            shouldDisplay: { app.activeEditor is TextEditorInstance },
            positionPreference: .left,
            positionPrecedence: Int.min
        )
        for item in [
            encodingStatusBarItem, lineColumnIndicatorStatusBarItem, readOnlyStatusBarItem,
            vimKeyBufferStatusBarItem, vimModeStatusBarItem,
        ] {
            contribution.statusBar.registerItem(item: item)
        }
    }
}
