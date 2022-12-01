//
//  LocalExecutionExtension.swift
//  Code
//
//  Created by Ken Chung on 19/11/2022.
//

import Foundation

private let EXTENSION_ID = "LOCAL_EXECUTION"

private let LOCAL_EXECUTION_COMMANDS = [
    "py": "python3 -u {url}",
    "js": "node {url}",
    "c": "clang {url} && wasm a.out",
    "cpp": "clang++ {url} && wasm a.out",
    "php": "php {url}",
]

class LocalExecutionExtension: CodeAppExtension {
    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {
        let toolbarItem = ToolbarItem(
            extenionID: EXTENSION_ID,
            icon: "play",
            onClick: {
                self.runCodeLocally(app: app)
            },
            shortCut: .init("r", modifiers: [.command]),
            panelToFocusOnTap: "TERMINAL",
            shouldDisplay: {
                guard let activeTextEditor = app.activeTextEditor else { return false }
                return activeTextEditor.url.isFileURL &&
                LOCAL_EXECUTION_COMMANDS[activeTextEditor.languageIdentifier] != nil
            }
        )
        contribution.toolbarItem.registerItem(item: toolbarItem)
    }

    private func runCodeLocally(app: MainApp) {

        guard let activeTextEditor = app.activeTextEditor else {
            return
        }

        guard let command = LOCAL_EXECUTION_COMMANDS[activeTextEditor.languageIdentifier] else {
            return
        }

        let sanitizedUrl = activeTextEditor.url.path.replacingOccurrences(of: " ", with: #"\ "#)
        let fullCommand = command.replacingOccurrences(of: "{url}", with: sanitizedUrl)

        let compilerShowPath = UserDefaults.standard.bool(forKey: "compilerShowPath")
        if compilerShowPath {
            app.terminalInstance.executeScript("localEcho.println(`\(fullCommand)`);readLine('');")
        } else {
            let commandName = command.components(separatedBy: " ").first ?? fullCommand
            app.terminalInstance.executeScript("localEcho.println(`\(commandName)`);readLine('');")
        }
        app.terminalInstance.executeScript(
            "window.webkit.messageHandlers.toggleMessageHandler2.postMessage({\"Event\": \"Return\", \"Input\": `\(fullCommand)`})"
        )
    }
}
