//
//  RemoteExecutionExtension.swift
//  Code
//
//  Created by Ken Chung on 14/11/2022.
//

import SwiftUI

private let EXTENSION_ID = "EXECUTION"
private let PANEL_ID = "panel.execution.title"

class RemoteExecutionExtension: CodeAppExtension {
    let storage = CloudCodeExecutionManager()

    override func onInitialize(
        app: MainApp,
        contribution: CodeAppExtension.Contribution
    ) {
        let panel = Panel(
            labelId: PANEL_ID,
            mainView: AnyView(PanelRemoteExecutionMainView().environmentObject(storage)),
            toolBarView: AnyView(PanelRemoteExecutionToolbarView().environmentObject(storage))
        )
        contribution.panel.registerPanel(panel: panel)

        let toolbarItem = ToolbarItem(
            extenionID: EXTENSION_ID,
            icon: "server.rack",
            secondaryIcon: "play.circle.fill",
            onClick: {
                if self.storage.displayMode == .input {
                    self.storage.displayMode = .output
                }
                guard let textEditor = app.activeEditor as? TextEditorInstance,
                    let languageCode = compilerCodeForPath(path: textEditor.url.absoluteString)
                else {
                    return
                }
                Task {
                    await app.saveCurrentFile()

                    self.storage.runCode(
                        directoryURL: textEditor.url, source: textEditor.content,
                        language: languageCode
                    )
                }
            },
            shortCut: .init("r", modifiers: [.command]),
            panelToFocusOnTap: PANEL_ID,
            shouldDisplay: {
                guard let textEditor = app.activeEditor as? TextEditorInstance else {
                    return false
                }
                return textEditor.url.isFileURL
                    && languageList.map { $0.value[1] }.contains(textEditor.languageIdentifier)
            }
        )
        contribution.toolbarItem.registerItem(item: toolbarItem)
    }
}

private struct InputView: View {
    @EnvironmentObject var manager: CloudCodeExecutionManager

    var body: some View {

        TextEditorWithPlaceholder(
            placeholder: "panel.execution.program_input",
            text: $manager.stdin,
            customFont: .custom("Menlo", size: 13, relativeTo: .footnote)
        )

    }
}

private struct OutputView: View {

    @EnvironmentObject var manager: CloudCodeExecutionManager

    var body: some View {
        Group {
            if manager.consoleContent.isEmpty {
                Text("panel.execution.press_play_to_execute_code")
                    .font(.footnote)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    Text(manager.consoleContent)
                        .foregroundColor(Color.init("T1"))
                        .font(.custom("Menlo", size: 13, relativeTo: .footnote))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

    }

}

private struct PanelRemoteExecutionMainView: View {

    @EnvironmentObject var manager: CloudCodeExecutionManager

    var body: some View {
        switch manager.displayMode {
        case .input:
            InputView()
        case .output:
            OutputView()
        case .split:
            HStack {
                InputView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                OutputView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        }
    }
}

private struct PanelRemoteExecutionToolbarView: View {

    @EnvironmentObject var manager: CloudCodeExecutionManager

    var body: some View {
        PanelSelector<PanelDisplayMode>(
            selection: $manager.displayMode,
            options: [
                .init(titleKey: "panel.execution.input", value: .input),
                .init(titleKey: "panel.execution.output", value: .output),
                .init(titleKey: "panel.execution.split_view", value: .split),
            ]
        )
    }
}

private let languageList = [
    62: ["Java (OpenJDK 13.0.1)", "java"],
    45: ["Assembly (NASM 2.14.02)", "asm"],
    //                    46:["Bash (5.0.0)", "sh"],
    47: ["Basic (FBC 1.07.1)", "bas"],
    //    75: ["C (Clang 7.0.1)", "c"],
    //    76: ["C++ (Clang 7.0.1)", "cpp"],
    //    48: ["C (GCC 7.4.0)", "c"],
    //    52: ["C++ (GCC 7.4.0)", "cpp"],
    //    49: ["C (GCC 8.3.0)", "c"],
    //    53: ["C++ (GCC 8.3.0)", "cpp"],
    50: ["C (GCC 9.2.0)", "c"],
    54: ["C++ (GCC 9.2.0)", "cpp"],
    51: ["C# (Mono 6.6.0.161)", "cs"],
    86: ["Clojure (1.10.1)", "clj"],
    77: ["COBOL (GnuCOBOL 2.2)", "cob"],
    55: ["Common Lisp (SBCL 2.0.0)", "lsp"],
    56: ["D (DMD 2.089.1)", "di"],
    57: ["Elixir (1.9.4)", "ex"],
    58: ["Erlang (OTP 22.2)", "erl"],
    //                    44:["Executable", "exe"],
    59: ["Fortran (GFortran 9.2.0)", "f90"],
    60: ["Go (1.13.5)", "go"],
    88: ["Groovy (3.0.3)", "groovy"],
    61: ["Haskell (GHC 8.8.1)", "hs"],
    //                    63:["JavaScript (Node.js 12.14.0)", "js"],
    78: ["Kotlin (1.3.70)", "kt"],
    64: ["Lua (5.3.5)", "lua"],
    79: ["Objective-C (Clang 7.0.1)", "m"],
    65: ["OCaml (4.09.0)", "ml"],
    66: ["Octave (5.1.0)", "oct"],
    67: ["Pascal (FPC 3.0.4)", "pas"],
    //                    68:["PHP (7.4.1)", "php"],
    //                    43:["Plain Text", "txt"],
    69: ["Prolog (GNU Prolog 1.4.5)", "pl"],
    //                    70:["Python (2.7.17)", "py"],
    //                    71:["PythonML (3.7.7)", "py"],
    80: ["R (4.0.0)", "r"],
    72: ["Ruby (2.7.0)", "rb"],
    73: ["Rust (1.40.0)", "rs"],
    81: ["Scala (2.13.2)", "scala"],
    82: ["SQL (SQLite 3.27.2)", "sql"],
    74: ["TypeScript (3.7.4)", "ts"],
    83: ["Swift (5.2.3)", "swift"],
    84: ["Visual Basic.Net (vbnc 0.0.0.5943)", "vb"],
]

private func compilerCodeForPath(path: String) -> Int? {
    let sortedLanguages = languageList.sorted(by: { $0.key < $1.key })
    return sortedLanguages.first(where: { path.hasSuffix(".\($0.value[1])") })?.key
}
