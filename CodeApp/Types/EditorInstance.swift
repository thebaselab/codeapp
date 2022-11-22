//
//  EditorInstance.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import Foundation
import MarkdownView
import SwiftUI

class EditorInstance: ObservableObject, Identifiable, Equatable, Hashable {
    static func == (lhs: EditorInstance, rhs: EditorInstance) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id = UUID()
    let view: AnyView
    var title: String

    init(view: AnyView, title: String) {
        self.view = view
        self.title = title
    }
}

class EditorInstanceWithURL: EditorInstance {
    var url: URL {
        didSet {
            title = url.lastPathComponent
        }
    }

    init(view: AnyView, title: String, url: URL) {
        self.url = url
        super.init(view: view, title: title)
    }
}

class TextEditorInstance: EditorInstanceWithURL {
    @Published var lastSavedVersionId = 1
    @Published var currentVersionId = 1

    var content: String
    let type: editorType
    var compareTo: String? = nil
    var encoding: String.Encoding = .utf8
    var fileWatch: FolderMonitor?
    var isDeleted = false

    var languageIdentifier: String {
        url.pathExtension
    }

    init(
        editor: MonacoEditor, url: URL, content: String, type: editorType,
        encoding: String.Encoding = .utf8,
        compareTo: String? = nil,
        fileDidChange: ((fileState, String?) -> Void)? = nil
    ) {
        self.content = content
        self.type = type
        self.encoding = encoding
        self.compareTo = compareTo
        super.init(view: AnyView(editor), title: url.lastPathComponent, url: url)

        if fileDidChange != nil, url.scheme == "file" {
            self.fileWatch = FolderMonitor(url: url)

            self.fileWatch?.folderDidChange = {
                if let content = try? String(contentsOf: url, encoding: self.encoding) {
                    if self.lastSavedVersionId == self.currentVersionId {
                        self.content = content
                        fileDidChange?(.modified, content)
                        self.lastSavedVersionId = self.currentVersionId
                    }
                }
            }
            self.fileWatch?.startMonitoring()
        }
    }

    deinit {
        self.fileWatch?.stopMonitoring()
    }

    enum fileState {
        case deleted
        case modified
    }

    enum editorType {
        case file
        case diff
    }
}