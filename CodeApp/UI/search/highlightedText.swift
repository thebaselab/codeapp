//
//  highlightedText.swift
//  Code App
//
//  @Alladinian
//  https://stackoverflow.com/questions/59426359/swiftui-is-there-exist-modifier-to-highlight-substring-of-text-view

import SwiftUI

struct HighlightedText: View {
    let text: String
    let matching: String
    let accentColor: Color

    init(_ text: String, matching: String, accentColor: Color) {
        self.text = text.trimmingCharacters(in: .whitespaces)
        self.matching = matching
        self.accentColor = accentColor
    }

    var body: some View {
        var subString = self.matching
        if let range = text.range(of: self.matching, options: .caseInsensitive) {
            subString = String(text[range.lowerBound..<range.upperBound])
        }
        let tagged = text.replacingOccurrences(
            of: self.matching, with: "<SPLIT>>\(subString)<SPLIT>", options: .caseInsensitive)
        let split = tagged.components(separatedBy: "<SPLIT>")
        return split.reduce(Text("").foregroundColor(Color.init("T1"))) { (a, b) -> Text in
            guard !b.hasPrefix(">") else {
                return a.foregroundColor(Color.init("T1"))
                    + Text(b.dropFirst()).foregroundColor(self.accentColor)
            }
            return a.foregroundColor(Color.init("T1")) + Text(b)
        }
    }
}
