//
//  LanguageService.swift
//  Code
//
//  Created by Ken Chung on 09/08/2024.
//

import Foundation

class LanguageService {
    struct Configuration {
        let languageIdentifier: String
        let extensions: [String]
        let args: [String]
    }

    var candidateLanguageIdentifier: String? = nil

    static let shared = LanguageService()
    static let configurations: [Configuration] = [
        Configuration(
            languageIdentifier: "python",
            extensions: ["py"],
            args: ["jedi-language-server", "-v"]),
        Configuration(
            languageIdentifier: "java",
            extensions: ["java"],
            args: ["java", "-jar", "${JAVA_LSP_FAT_JAR_PATH}"]),
            Configuration(
                languageIdentifier: "fsharp",
                extensions: ["fs", "fsi", "fsx", "fsproj"],
                args: ["dotnet", "fsautocomplete"] // Uses fsautocomplete, the F# LSP server
            ),
    ]

    static func configurationFor(url: URL) -> Configuration? {
        return LanguageService.configurations.first(where: {
            $0.extensions.contains(url.pathExtension)
        })
    }
}
