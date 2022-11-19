//
//  ToolbarItem.swift
//  Code
//
//  Created by Ken Chung on 14/11/2022.
//

import SwiftUI

struct ToolbarItem: Identifiable {
    let id = UUID()
    var extenionID: String
    var icon: String
    var onClick: () -> Void
    var shortCut: KeyboardShortcut?
    var panelToFocusOnTap: String?
    var shouldDisplay: () -> Bool
}
