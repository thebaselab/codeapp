//
//  CodeAppExtension.swift
//  Code
//
//  Created by Ken Chung on 14/11/2022.
//

import Foundation

class CodeAppExtension {
    class Contribution {
        var panel: PanelManager
        var toolbarItem: ToolbarManager
        var editorProvider: EditorProviderManager

        init(
            panel: PanelManager, toolbarItem: ToolbarManager, editorProvider: EditorProviderManager
        ) {
            self.panel = panel
            self.toolbarItem = toolbarItem
            self.editorProvider = editorProvider
        }
    }

    func onInitialize(
        app: MainApp,
        contribution: CodeAppExtension.Contribution
    ) {

    }

    func onWorkSpaceStorageChanged(newUrl: URL) {

    }

}
