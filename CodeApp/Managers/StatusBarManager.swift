//
//  StatusBarManager.swift
//  Code
//
//  Created by Ken Chung on 15/8/2023.
//

import SwiftUI

struct StatusBarItem: Identifiable {
    let id = UUID()
    var extensionID: String
    var view: AnyView
    var shouldDisplay: (MainApp) -> Bool
    var positionPreference: PositionPreference
    var positionPrecedence: Int = 0

    enum PositionPreference {
        case left, right
    }
}

class StatusBarManager: CodeAppContributionPointManager {
    @Published var items: [StatusBarItem] = []
}
