//
//  SourceControlExtension.swift
//  Code
//
//  Created by Ken Chung on 24/11/2022.
//

import Foundation
import SwiftUI

private let EXTENSION_ID = "SOURCE_CONTROL_AUX"

class SourceControlAuxiliaryExtension: CodeAppExtension {
    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {
        let compareWithPreviousitem = ToolbarItem(
            extenionID: EXTENSION_ID,
            icon: "arrow.2.squarepath",
            onClick: { onCompareWithPreviousItemClick(app: app) },
            shouldDisplay: { app in
                app.activeEditor is TextEditorInstance
                    && !(app.activeEditor is DiffTextEditorInstnace) && app.gitTracks.count > 0
            }
        )
        let previousChangeItem = ToolbarItem(
            extenionID: EXTENSION_ID,
            icon: "arrow.up",
            onClick: {
                Task {
                    await app.monacoInstance.moveToPreviousDiff()
                }
            },
            shouldDisplay: { app in
                app.activeEditor is DiffTextEditorInstnace
            }
        )
        let nextChangeItem = ToolbarItem(
            extenionID: EXTENSION_ID,
            icon: "arrow.down",
            onClick: {
                Task {
                    await app.monacoInstance.moveToNextDiff()
                }
            },
            shouldDisplay: { app in
                app.activeEditor is DiffTextEditorInstnace
            }
        )
        let aheadBehindIndicatorItem = StatusBarItem(
            extensionID: EXTENSION_ID,
            view: AnyView(AheadBehindIndicator()),
            shouldDisplay: { app in app.aheadBehind != nil },
            positionPreference: .left
        )
        let checkoutMenuItem = StatusBarItem(
            extensionID: EXTENSION_ID,
            view: AnyView(CheckoutMenu()),
            shouldDisplay: { app in !app.branch.isEmpty },
            positionPreference: .left,
            positionPrecedence: 1
        )

        contribution.toolBar.registerItem(item: compareWithPreviousitem)
        contribution.toolBar.registerItem(item: previousChangeItem)
        contribution.toolBar.registerItem(item: nextChangeItem)
        contribution.statusBar.registerItem(item: aheadBehindIndicatorItem)
        contribution.statusBar.registerItem(item: checkoutMenuItem)
    }
}

private func onCompareWithPreviousItemClick(app: MainApp) {
    guard let url = app.activeTextEditor?.url else {
        return
    }
    Task {
        do {
            try await app.notificationManager.withAsyncNotification(
                title: "source_control.retrieving_changes",
                task: {
                    try await app.compareWithPrevious(url: url.standardizedFileURL)
                })
        } catch {
            app.notificationManager.showErrorMessage(error.localizedDescription)
        }
    }
}
