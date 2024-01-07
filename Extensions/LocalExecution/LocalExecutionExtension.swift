//
//  LocalExecutionExtension.swift
//  Code
//
//  Created by Ken Chung on 19/11/2022.
//

import Foundation

private let EXTENSION_ID = "LOCAL_EXECUTION"

private let LOCAL_EXECUTION_COMMANDS = [
    "py": ["python3 -u {url}"],
    "js": ["node {url}"],
    "c": ["clang {url}", "wasm a.out"],
    "cpp": ["clang++ {url}", "wasm a.out"],
    "php": ["php {url}"],
    "java": [
        "javac {url}",
        "java -classpath \"{url_parent}\" \"{last_path_component_without_extension}\"",
    ],
]

class LocalExecutionExtension: CodeAppExtension {
    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {
        let toolbarItem = ToolbarItem(
            extenionID: EXTENSION_ID,
            icon: "play",
            onClick: {
                Task {
                    await self.runCodeLocally(app: app)
                }
            },
            shortCut: .init("r", modifiers: [.command]),
            panelToFocusOnTap: "TERMINAL",
            shouldDisplay: {
                guard let activeTextEditor = app.activeTextEditor else { return false }
                return activeTextEditor.url.isFileURL
                    && LOCAL_EXECUTION_COMMANDS[activeTextEditor.languageIdentifier] != nil
            }
        )
        contribution.toolBar.registerItem(item: toolbarItem)
    }

    private func runCodeLocally(app: MainApp) async {

        guard app.terminalInstance.executor?.state == .idle else { return }

        guard let activeTextEditor = app.activeTextEditor else {
            return
        }

        guard let commands = LOCAL_EXECUTION_COMMANDS[activeTextEditor.languageIdentifier] else {
            return
        }

        await app.saveCurrentFile()

        let sanitizedUrl = activeTextEditor.url.path.replacingOccurrences(of: " ", with: #"\ "#)
        let urlParent = activeTextEditor.url.deletingLastPathComponent().path
        let lastPathComponentWithoutExtension = activeTextEditor.url.deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: " ", with: #"\ "#)
        let parsedCommands = commands.map {
            $0
                .replacingOccurrences(of: "{url}", with: sanitizedUrl)
                .replacingOccurrences(of: "{url_parent}", with: urlParent)
                .replacingOccurrences(
                    of: "{last_path_component_without_extension}",
                    with: lastPathComponentWithoutExtension)
        }

        let compilerShowPath = UserDefaults.standard.bool(forKey: "compilerShowPath")
        if compilerShowPath {
            app.terminalInstance.executeScript(
                "localEcho.println(`\(parsedCommands.joined(separator: " && "))`);readLine('');")
        } else {
            let commandName =
                parsedCommands.first?.components(separatedBy: " ").first
                ?? activeTextEditor.languageIdentifier
            app.terminalInstance.executeScript("localEcho.println(`\(commandName)`);readLine('');")
        }
        app.terminalInstance.executor?.evaluateCommands(parsedCommands)
    }
}
