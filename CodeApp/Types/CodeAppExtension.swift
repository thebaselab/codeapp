//
//  CodeAppExtension.swift
//  Code
//
//  Created by Ken Chung on 14/11/2022.
//

import Foundation

class CodeAppExtension {
    struct Contribution {
        var panel: PanelManager
        var toolbarItem: ToolbarManager
        var editorProvider: EditorProviderManager
    }

    func onInitialize(
        app: MainApp,
        contribution: CodeAppExtension.Contribution
    ) {

    }

}
