//
//  urlToDisplayName.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

func editorDisplayName(editor: EditorInstance) -> String{
    if editor.type == .diff {
        let name1 = editor.url.components(separatedBy: "/").last?.removingPercentEncoding ?? ""
        let name2 = editor.compareTo!.components(separatedBy: "/").last?.removingPercentEncoding ?? ""
        if editor.compareTo!.hasPrefix("file://previous"){
            return "\(name1) (Working Tree)"
        }
        return "\(name2) ↔ \(name1)"
    }
    if editor.url.hasSuffix("{welcome}"){
        return NSLocalizedString("Welcome", comment: "")
    }
    if editor.type == .preview{
        let name = editor.url.replacingOccurrences(of:"{preview}", with: "").components(separatedBy: "/").last?.removingPercentEncoding ?? ""
        return "Preview: " + name
    }
    return editor.url.components(separatedBy: "/").last?.removingPercentEncoding ?? ""
}
