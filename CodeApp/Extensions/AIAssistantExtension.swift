//
//  AIAssistantExtension.swift
//  CodeApp
//
//  Created by Codex.
//

import SwiftUI

private let AI_ASSISTANT_EXTENSION_ID = "AI_ASSISTANT"

extension Notification.Name {
    static let codeAssistantToggleRequested = Notification.Name("codeassistant.toggleRequested")
}

class AIAssistantExtension: CodeAppExtension {
    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {
        let toolbarItem = ToolbarItem(
            extenionID: AI_ASSISTANT_EXTENSION_ID,
            icon: "bolt.horizontal.circle",
            onClick: {
                NotificationCenter.default.post(name: .codeAssistantToggleRequested, object: nil)
            },
            shouldDisplay: { _ in true }
        )
        contribution.toolBar.registerItem(item: toolbarItem)
    }
}
