//
//  MarkdownViewerExtension.swift
//  Code
//
//  Created by Ken Chung on 23/11/2022.
//

import MarkdownView
import SwiftUI

// TODO: Localization

private struct MarkdownPreview: UIViewRepresentable {

    weak var view: MarkdownView?

    func updateUIView(_ uiView: MarkdownView, context: Context) {
        uiView.changeBackgroundColor(color: UIColor(id: "editor.background"))
    }

    func makeUIView(context: Context) -> MarkdownView {
        return view ?? MarkdownView()
    }
}

class MarkdownEditorInstance: EditorInstanceWithURL {

    let mdView = MarkdownView()

    func load(content: String) {
        mdView.load(markdown: content, backgroundColor: UIColor(id: "editor.background"))
    }

    init(url: URL, content: String, title: String) {
        super.init(view: AnyView(MarkdownPreview(view: mdView).id(UUID())), title: title, url: url)
        load(content: content)
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
                let instance = MarkdownEditorInstance(
                    url: url,
                    content: content, title: "Preview: " + url.lastPathComponent)
                instance.fileWatch?.folderDidChange = { _ in
                    Task {
                        let contentData = try await app.workSpaceStorage.contents(at: url)
                        if let content = String(data: contentData, encoding: .utf8) {
                            await MainActor.run {
                                instance.load(content: content)
                            }
                        }
                    }
                }
                instance.fileWatch?.startMonitoring()

                DispatchQueue.main.async {
                    app.appendAndFocusNewEditor(editor: instance, alwaysInNewTab: true)
                }
            },
            shouldDisplay: { app in
                ["md", "markdown"].contains(app.activeTextEditor?.languageIdentifier.lowercased())
            }
        )
        contribution.toolBar.registerItem(item: item)
    }

}
