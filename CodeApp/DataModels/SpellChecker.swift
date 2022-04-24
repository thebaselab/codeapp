//
//  SpellChecker.swift
//  Code
//
//  Created by Ken Chung on 23/4/2022.
//

import Foundation
import NaturalLanguage
import UIKit

class SpellChecker {
    static let shared = SpellChecker()

    private let checker = UITextChecker()
    private let tokenizer = NLTokenizer(unit: .word)
    private let queue = DispatchQueue.global(qos: .utility)

    private let options: NLTagger.Options = [
        .omitPunctuation,
        .omitWhitespace,
        .joinNames,
    ]

    struct SpellProblem: Codable {
        let offset: Int
        let length: Int
        let message: String
    }

    private func _check(text: String, uri: String, startOffset: Int = 0, endOffset: Int = 0) {
        var spellProblems: [SpellProblem] = []
        let endIndex =
            endOffset == 0 ? text.endIndex : text.index(text.startIndex, offsetBy: endOffset)
        let range = text.index(text.startIndex, offsetBy: startOffset)..<endIndex
        tokenizer.string = text

        tokenizer.enumerateTokens(in: range) { tokenRange, _ in
            let word = text[tokenRange]
            let misspelledRange = checker.rangeOfMisspelledWord(
                in: String(word), range: NSRange(0..<word.utf16.count),
                startingAt: 0, wrap: false, language: "en")
            if misspelledRange.location != NSNotFound {
                let length = text.distance(
                    from: tokenRange.lowerBound, to: tokenRange.upperBound)
                spellProblems.append(
                    SpellProblem(
                        offset: text.distance(from: text.startIndex, to: tokenRange.lowerBound),
                        length: length, message: "Potentially misspelled word '\(word)'"))
            }
            return true
        }

        if spellProblems.isEmpty, endOffset != 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                monacoWebView.evaluateJavaScript(
                    "invalidateDiagnosticForOffset(\(startOffset), \(endOffset))"
                ) {
                    result, error in

                }
            }
            return
        }

        let jsonData = try! JSONEncoder().encode(spellProblems)
        let jsonStr = String(data: jsonData, encoding: .utf8)!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            monacoWebView.evaluateJavaScript(
                "provideDiagnostic(\(jsonStr), '\(uri)')"
            ) {
                result, error in

            }
        }
    }

    func check(text: String, uri: String, startOffset: Int = 0, endOffset: Int = 0) {
        if !(uri.hasSuffix(".md") || uri.hasSuffix(".txt")) {
            return
        }
        print("Providing Spelling Diagnostic for \(uri)")
        queue.async {
            self._check(text: text, uri: uri, startOffset: startOffset, endOffset: endOffset)
        }
    }
}
