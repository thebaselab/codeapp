//
//  PanelManager.swift
//  Code
//
//  Created by Ken Chung on 15/11/2022.
//

import SwiftUI

private let DEFAULT_FOCUSED_PANEL_ID = "TERMINAL"

struct Panel {
    let labelId: String
    let mainView: AnyView
    let toolBarView: AnyView?
}

class PanelManager: ObservableObject {
    @Published var panels: [Panel] = []
    @Published var bubbleCount: [String: Int] = [:]

    func registerPanel(panel: Panel) {
        panels.append(panel)
    }

    func deregisterPanel(id: String) {
        panels.removeAll(where: { $0.labelId == id })
    }

    func setBubbleCountForPanel(id: String, value: Int?) {
        if let value = value {
            bubbleCount[id] = value
        } else {
            bubbleCount.removeValue(forKey: id)
        }
    }
}
