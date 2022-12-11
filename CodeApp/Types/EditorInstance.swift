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
    
    @Published var title: String
    let id = UUID()
    let view: AnyView

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
    var pathAfterUUID: String {
        let uuidRegex = try! NSRegularExpression(
            pattern: "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
            options: .caseInsensitive)
        let lastMatchIndex =
            uuidRegex.matches(
                in: url.path, options: [], range: NSRange(location: 0, length: url.path.count)
            ).last?.range.location ?? 0
        return String(
            url.path.suffix(
                from: url.path.index(url.path.startIndex, offsetBy: lastMatchIndex + 37)))
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
    var encoding: String.Encoding = .utf8
    var fileWatch: FolderMonitor?
    var isDeleted = false
    var lastSavedDate: Date? = nil

    var languageIdentifier: String {
        url.pathExtension
    }
    var isSaved: Bool {
        lastSavedVersionId == currentVersionId
    }

    init(
        editor: MonacoEditor,
        url: URL,
        content: String,
        encoding: String.Encoding = .utf8,
        lastSavedDate: Date? = nil,
        fileDidChange: ((fileState, String?) -> Void)? = nil
    ) {
        self.content = content
        self.encoding = encoding
        self.lastSavedDate = lastSavedDate
        super.init(view: AnyView(editor), title: url.lastPathComponent, url: url)

        if fileDidChange != nil, url.scheme == "file" {
            self.fileWatch = FolderMonitor(url: url)

            self.fileWatch?.folderDidChange = { [weak self] lastModified in
                guard let self = self else { return }

                guard let content = try? String(contentsOf: url, encoding: self.encoding) else {
                    return
                }

                DispatchQueue.main.async {
                    if lastModified > self.lastSavedDate ?? Date.distantPast, self.isSaved {
                        self.content = content
                        self.lastSavedDate = lastModified
                        fileDidChange?(.modified, content)
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
}

class DiffTextEditorInstnace: TextEditorInstance {
    var compareWith: String

    init(
        editor: MonacoEditor,
        url: URL,
        content: String,
        encoding: String.Encoding = .utf8,
        compareWith: String,
        fileDidChange: ((fileState, String?) -> Void)? = nil
    ) {
        self.compareWith = compareWith
        super.init(
            editor: editor, url: url, content: content, encoding: encoding,
            fileDidChange: fileDidChange)
    }
}
