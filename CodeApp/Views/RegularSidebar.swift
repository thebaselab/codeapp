//
//  RegularSidebar.swift
//  Code
//
//  Created by Ken Chung on 14/8/2023.
//

import SwiftUI

private var EDITOR_MIN_WIDTH: CGFloat = 200.0
private var REGULAR_SIDEBAR_MIN_WIDTH: CGFloat = DefaultUIState.SIDEBAR_WIDTH

struct RegularSidebar: View {
    @EnvironmentObject var activityBarManager: ActivityBarManager

    @SceneStorage("sidebar.width") var sideBarWidth: Double = DefaultUIState.SIDEBAR_WIDTH
    @SceneStorage("activitybar.selected.item") var activeItemId: String = DefaultUIState
        .ACTIVITYBAR_SELECTED_ITEM
    @SceneStorage("sidebar.visible") var isSideBarVisible: Bool = DefaultUIState.SIDEBAR_VISIBLE

    @GestureState var sideBarWidthTranslation: CGFloat = 0
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var maxWidth: CGFloat {
        windowWidth
            - UIApplication.shared.getSafeArea(edge: .left)
            - UIApplication.shared.getSafeArea(edge: .right)
            - ACTIVITY_BAR_WIDTH
            - EDITOR_MIN_WIDTH
    }
    var windowWidth: CGFloat

    func evaluateProposedWidth(proposal: CGFloat) {
        if proposal < REGULAR_SIDEBAR_MIN_WIDTH {
            sideBarWidth = DefaultUIState.SIDEBAR_WIDTH
        } else if proposal > maxWidth {
            sideBarWidth = maxWidth
        } else {
            sideBarWidth = proposal
        }
    }

    var body: some View {
        ZStack(alignment: .center) {
            Color.init(id: "sideBar.background")
            if let item = activityBarManager.itemForItemID(itemID: activeItemId), item.isVisible() {
                item.view
            } else {
                ProgressView()
            }
        }
        .gesture(
            DragGesture()
                .updating($sideBarWidthTranslation) { value, state, transaction in
                    state = value.translation.width
                }
                .onEnded { value in
                    let proposedNewHeight = sideBarWidth + value.translation.width
                    evaluateProposedWidth(proposal: proposedNewHeight)
                }
        )
        .frame(
            width: min(
                max(sideBarWidth + sideBarWidthTranslation, REGULAR_SIDEBAR_MIN_WIDTH),
                maxWidth
            )
        )
        .background(Color.init(id: "sideBar.background"))
    }
}
