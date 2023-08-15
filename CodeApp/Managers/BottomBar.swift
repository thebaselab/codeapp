//
//  bottomBar.swift
//  Code
//
//  Created by Ken Chung on 1/7/2021.
//

import SwiftGit2
import SwiftUI

struct StatusBar: View {
    @EnvironmentObject var App: MainApp
    @EnvironmentObject var statusBarManager: StatusBarManager

    var leftMostItems: [StatusBarItem] {
        statusBarManager.items
            .filter { $0.shouldDisplay() }
            .filter { $0.positionPreference == .left }
            .sorted { $0.positionPrecedence > $1.positionPrecedence }
    }
    var rightMostItems: [StatusBarItem] {
        statusBarManager.items
            .filter { $0.shouldDisplay() }
            .filter { $0.positionPreference == .right }
            .sorted { $0.positionPrecedence < $1.positionPrecedence }
    }

    var body: some View {
        ZStack {
            Color.init(id: "statusBar.background")
            HStack(spacing: 4) {
                ForEach(leftMostItems) { item in
                    item.view
                }
                Spacer()
                ForEach(rightMostItems) { item in
                    item.view
                }
            }
            .padding(.horizontal, [UIApplication.shared.getSafeArea(edge: .bottom), 5].max())
        }
        .font(.system(size: 12))
        .foregroundColor(Color.init(id: "statusBar.foreground"))
        .background(Color.init(id: "statusBar.background"))
        .frame(height: 20)
    }
}
