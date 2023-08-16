//
//  ActivityBarManager.swift
//  Code
//
//  Created by Ken Chung on 15/8/2023.
//

import SwiftUI

struct ActivityBarItem: Identifiable {
    let id = UUID()
    let itemID: String
    let iconSystemName: String
    let title: LocalizedStringKey
    let shortcutKey: KeyEquivalent
    let modifiers: EventModifiers
    let view: AnyView
    let positionPrecedence: Int = 0
    let contextMenuItems: (() -> [ContextMenuItem])?
    var bubbleText: () -> String?
}

class ActivityBarManager: CodeAppContributionPointManager {
    @Published var items: [ActivityBarItem] = []

    func itemForItemID(itemID: String) -> ActivityBarItem? {
        return items.first { $0.itemID == itemID }
    }
}
