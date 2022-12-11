//
//  SourceControlExtension.swift
//  Code
//
//  Created by Ken Chung on 24/11/2022.
//

import Foundation

private let EXTENSION_ID = "SOURCE_CONTROL_AUX"

class SourceControlAuxiliaryExtension: CodeAppExtension {
    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {
        let compareWithPreviousitem = ToolbarItem(
            extenionID: EXTENSION_ID,
            icon: "arrow.2.squarepath",
            onClick: {
                guard let url = app.activeTextEditor?.url else {
                    return
                }
                Task {
                    try await app.compareWithPrevious(url: url.standardizedFileURL)
                }
            },
            shouldDisplay: {
                app.activeEditor is TextEditorInstance
                    && !(app.activeEditor is DiffTextEditorInstnace) && app.gitTracks.count > 0
            }
        )

        let previousChangeItem = ToolbarItem(
            extenionID: EXTENSION_ID,
            icon: "arrow.up",
            onClick: {
                app.monacoInstance.executeJavascript(command: "navi.previous()")
            },
            shouldDisplay: {
                app.activeEditor is DiffTextEditorInstnace
            }
        )

        let nextChangeItem = ToolbarItem(
            extenionID: EXTENSION_ID,
            icon: "arrow.down",
            onClick: {
                app.monacoInstance.executeJavascript(command: "navi.next()")
            },
            shouldDisplay: {
                app.activeEditor is DiffTextEditorInstnace
            }
        )

        contribution.toolbarItem.registerItem(item: compareWithPreviousitem)
        contribution.toolbarItem.registerItem(item: previousChangeItem)
        contribution.toolbarItem.registerItem(item: nextChangeItem)
    }
}
