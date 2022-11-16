//
//  searchManager.swift
//  Code
//
//  Created by Ken Chung on 12/4/2021.
//

import Foundation
import ios_system

class TextSearchManager: ObservableObject {

    @Published var searchTerm = ""
    @Published var message = ""
    @Published var expansionStates: [String: Bool] = [:]
    @Published var results: [String: [SearchResult]] = [:]

    var executor: Executor? = nil
    private var resultCount = 0

    private var tempResponse = ""

    init() {
        executor = Executor(
            root: URL(fileURLWithPath: FileManager().currentDirectoryPath),
            onStdout: { data in
                if let mes = String(data: data, encoding: .utf8) {
                    self.tempResponse += mes
                }
            },
            onStderr: { data in
                if let mes = String(data: data, encoding: .utf8) {
                    self.tempResponse += mes
                }
            },
            onRequestInput: { data in
                self.tempResponse += data
            })
    }

    private func parseResult() {
        for line in tempResponse.components(separatedBy: "\n") {
            let components = line.components(separatedBy: ":")
            if components.count < 3 {
                continue
            }
            let path = components[0]
            guard let linenum = Int(components[1]), FileManager.default.fileExists(atPath: path)
            else {
                continue
            }
            let line = components.dropFirst(2).joined().trimmingCharacters(in: .whitespaces)
            if expansionStates[path] == nil {
                expansionStates[path] = true
            }
            resultCount += 1
            if results[path] == nil {
                results[path] = [SearchResult(line_num: linenum, line: line)]
            } else {
                results[path]?.append(SearchResult(line_num: linenum, line: line))
            }
        }
        self.message =
            "\(self.resultCount) result\(self.resultCount > 1 ? "s" : "") in \(self.results.keys.count) file\(self.results.keys.count > 1 ? "s" : "")"
    }

    func removeAllResults() {
        results.removeAll()
        message.removeAll()
    }

    func search(str: String, path: String) {
        results = [:]
        resultCount = 0
        executor?.dispatch(
            command:
                "grep -rin --exclude-dir=node_modules --exclude-dir='.git' -m 1000 \"\(str.replacingOccurrences(of: "\"", with: #"\""#))\" \"\(path)\""
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.parseResult()
                self.tempResponse = ""
            }
        }
    }
}
