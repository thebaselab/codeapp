//
//  MarkdownViewerExtension.swift
//  Code
//
//  Created by Ken Chung on 23/11/2022.
//

import SwiftUI
import MarkdownView

// TODO: Localization

private struct MarkdownPreview: UIViewRepresentable {

    let view: MarkdownView

    func updateUIView(_ uiView: MarkdownView, context: Context) {
        view.changeBackgroundColor(color: UIColor(id: "editor.background"))
    }

    func makeUIView(context: Context) -> MarkdownView {
        return view
    }
}

private class MarkdownEditorInstance: EditorInstance {
    init(content: String, title: String) {
        let mdView = MarkdownView()
        mdView.load(markdown: content, backgroundColor: UIColor(id: "editor.background"))
        super.init(view: AnyView(MarkdownPreview(view: mdView).id(UUID())), title: title)
    }
}

class MarkdownViewerExtension: CodeAppExtension {
    
    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {
        let item = ToolbarItem(
            extenionID: "MARKDOWN",
            icon: "newspaper",
            onClick: {
                guard let content = app.activeTextEditor?.content,
                      let url = app.activeTextEditor?.url
                else {
                    return
                }
                let instance = MarkdownEditorInstance(content: content, title: "Preview: " + url.lastPathComponent)
                app.appendAndFocusNewEditor(editor: instance, alwaysInNewTab: true)
            },
            shouldDisplay: {
                ["md", "markdown"].contains(app.activeTextEditor?.languageIdentifier.lowercased())
            }
        )
        contribution.toolbarItem.registerItem(item: item)
    }
    
}
