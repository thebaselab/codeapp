//
//  ExtensionManager.swift
//  Code
//
//  Created by Ken Chung on 14/11/2022.
//

import Foundation

class ExtensionManager: ObservableObject {
    @Published var panelManager = PanelManager()
    @Published var toolbarManager = ToolbarManager()
    @Published var editorProviderManager = EditorProviderManager()

    private var extensions: [CodeAppExtension] = [
        MonacoIntellisenseExtension(),
        RemoteExecutionExtension(),
        LocalExecutionExtension(),
        TerminalExtension(),
        ImageViewerExtension(),
        VideoViewerExtension(),
        PDFViewerExtension(),
        MarkdownViewerExtension(),
        SourceControlAuxiliaryExtension(),
        SimpleWebPreviewExtension(),
    ]

    func registerExtension(ex: CodeAppExtension) {
        extensions.append(ex)
    }

    func initializeExtensions(app: MainApp) {
        let contribution = CodeAppExtension.Contribution(
            panel: self.panelManager,
            toolbarItem: self.toolbarManager,
            editorProvider: self.editorProviderManager
        )

        extensions.forEach { ex in
            ex.onInitialize(
                app: app,
                contribution: contribution
            )
        }
    }

    func onWorkSpaceStorageChanged(newUrl: URL) {
        extensions.forEach { ex in
            ex.onWorkSpaceStorageChanged(newUrl: newUrl)
        }
    }
}
