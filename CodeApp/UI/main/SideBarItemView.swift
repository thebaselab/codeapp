//
//  ActivityBarItemView.swift
//  Code
//
//  Created by Ken Chung on 14/4/2022.
//

import SwiftUI

struct ContextMenuItem {
    let id = UUID()
    let action: () -> Void
    let text: String
    let imageSystemName: String
}

struct ActivityBarItem {
    let action: () -> Void
    let isActive: Bool
    let iconSystemName: String
    let title: String
    let shortcutKey: KeyEquivalent
    let modifiers: EventModifiers
    let useBubble: Bool

    let bubbleText: String?
    let contextMenuItems: [ContextMenuItem]?
}

struct ActivityBarItemView: View {

    let activityBarItem: ActivityBarItem

    var body: some View {
        ZStack {
            Button(action: {
                activityBarItem.action()
            }) {
                ZStack {
                    Text(activityBarItem.title)
                        .foregroundColor(.clear)
                        .font(.system(size: 1))

                    Image(systemName: activityBarItem.iconSystemName)
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(
                            Color.init(
                                id: (activityBarItem.isActive)
                                    ? "activityBar.foreground"
                                    : "activityBar.inactiveForeground")
                        )
                        .padding(5)
                }.frame(maxWidth: .infinity, minHeight: 60.0)
            }
            .keyboardShortcut(activityBarItem.shortcutKey, modifiers: activityBarItem.modifiers)
            .if(activityBarItem.contextMenuItems != nil) { view in
                view
                    .contextMenu {
                        ForEach(activityBarItem.contextMenuItems!, id: \.id) { item in
                            Button(action: {
                                item.action()
                            }) {
                                Text(item.text)
                                Image(systemName: item.imageSystemName)
                            }
                        }
                    }
            }

            if activityBarItem.useBubble {
                if activityBarItem.bubbleText != nil {
                    ZStack {
                        Text("\(activityBarItem.bubbleText ?? " ")")
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 3)
                    .foregroundColor(
                        Color.init(id: "statusBar.foreground")
                    )
                    .background(
                        Color.init(id: "statusBar.background")
                    )
                    .cornerRadius(5)
                    .offset(x: 10, y: -10)
                } else {
                    Circle()
                        .fill(Color.init(id: "statusBar.background"))
                        .frame(width: 10, height: 10)
                        .offset(x: 10, y: -10)
                }

            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(minWidth: 0, maxWidth: 50.0, minHeight: 0, maxHeight: 60.0)
    }
}
