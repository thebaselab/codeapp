//
//  ActivityBarManager.swift
//  Code
//
//  Created by Ken Chung on 15/8/2023.
//

import SwiftUI

enum ActivityBarBubble {
    case text(String)
    case systemImage(String)
}

struct ActivityBarItem: Identifiable {
    let id = UUID()
    let itemID: String
    var iconSystemName: String
    var title: LocalizedStringKey
    var shortcutKey: KeyEquivalent?
    var modifiers: EventModifiers?
    var view: AnyView
    var contextMenuItems: (() -> [ContextMenuItem])?
    var positionPrecedence: Int = 0
    var bubble: () -> ActivityBarBubble?
    var isVisible: (() -> Bool)
}

class ActivityBarManager: CodeAppContributionPointManager {
    @Published var items: [ActivityBarItem] = []

    func itemForItemID(itemID: String) -> ActivityBarItem? {
        return items.first { $0.itemID == itemID }
    }
}
