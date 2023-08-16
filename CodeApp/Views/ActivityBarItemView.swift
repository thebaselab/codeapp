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

struct ActivityBarIconView: View {

    @EnvironmentObject var activityBarManager: ActivityBarManager
    let activityBarItem: ActivityBarItem

    @SceneStorage("activitybar.selected.item") var activeItemId: String = DefaultUIState
        .ACTIVITYBAR_SELECTED_ITEM
    @SceneStorage("sidebar.visible") var isSideBarVisible: Bool = DefaultUIState.SIDEBAR_VISIBLE

    var body: some View {
        ZStack {
            Button(action: {
                if isSideBarVisible && activeItemId == activityBarItem.itemID {
                    withAnimation(.easeIn(duration: 0.2)) {
                        isSideBarVisible = false
                    }
                } else {
                    activeItemId = activityBarItem.itemID
                    withAnimation(.easeIn(duration: 0.2)) {
                        isSideBarVisible = true
                    }
                }
            }) {
                ZStack {
                    Text(activityBarItem.title)
                        .foregroundColor(.clear)
                        .font(.system(size: 1))

                    Image(systemName: activityBarItem.iconSystemName)
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(
                            Color.init(
                                id: (activeItemId == activityBarItem.itemID && isSideBarVisible)
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
                        ForEach(activityBarItem.contextMenuItems!(), id: \.id) { item in
                            Button(action: {
                                item.action()
                            }) {
                                Text(item.text)
                                Image(systemName: item.imageSystemName)
                            }
                        }
                    }
            }

            if let bubbleText = activityBarItem.bubbleText() {
                if bubbleText.isEmpty {
                    Circle()
                        .fill(Color.init(id: "statusBar.background"))
                        .frame(width: 10, height: 10)
                        .offset(x: 10, y: -10)
                } else {
                    ZStack {
                        Text(bubbleText)
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
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(minWidth: 0, maxWidth: 50.0, minHeight: 0, maxHeight: 60.0)
    }
}
