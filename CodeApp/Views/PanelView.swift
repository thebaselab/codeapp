//
//  panel.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI
import ios_system

private let PANEL_MINIMUM_HEIGHT: CGFloat = 40
private let TOP_BAR_HEIGHT: CGFloat = 40
private let EDITOR_MINIMUM_HEIGHT: CGFloat = 8
private let BOTTOM_BAR_HEIGHT: CGFloat = 20

struct PanelToolbarButton: View {
    let systemName: String
    let onTapGesture: () -> Void

    var body: some View {
        Button(action: onTapGesture) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .light))
                .foregroundColor(Color.init(id: "panelTitle.activeForeground"))
                .padding(3)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .hoverEffect(.highlight)
                .frame(minWidth: 0, maxWidth: 8, minHeight: 0, maxHeight: 8)
                .padding(.horizontal)
        }
    }
}

private struct PanelTabLabel: View {
    let panel: Panel
    @SceneStorage("panel.focusedId") var currentPanelId: String = DefaultUIState.PANEL_FOCUSED_ID

    var body: some View {
        Text(LocalizedStringKey(panel.labelId))
            .textCase(.uppercase)
            .foregroundColor(
                Color.init(
                    id: panel.labelId == currentPanelId
                        ? "panelTitle.activeForeground" : "panelTitle.inactiveForeground")
            )
            .font(.system(size: 12, weight: .light))
            .padding(.leading)
            .onTapGesture {
                currentPanelId = panel.labelId
            }
    }
}

private struct PanelTabs: View {
    @EnvironmentObject var panelManager: PanelManager

    var body: some View {
        ForEach(panelManager.panels, id: \.labelId) { panel in
            PanelTabLabel(panel: panel)

            if let bubbleCount = panelManager.bubbleCount[panel.labelId] {
                Circle()
                    .fill(Color.init(id: "panel.border"))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Text("\(bubbleCount)")
                            .foregroundColor(Color.init(id: "panelTitle.activeForeground"))
                            .font(.system(size: 10))
                    )
            }
        }
    }

}

private struct Implementation: View {

    @EnvironmentObject var panelManager: PanelManager
    @SceneStorage("panel.focusedId") var currentPanelId: String = DefaultUIState.PANEL_FOCUSED_ID

    var currentPanel: Panel? {
        panelManager.panels.first(where: { $0.labelId == currentPanelId })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Rectangle()
                    .frame(minWidth: 0, maxWidth: .infinity, maxHeight: 1)
                    .foregroundColor(
                        Color.init(id: "panel.border"))
            }

            HStack {
                PanelTabs()

                Spacer()

                currentPanel?
                    .toolBarView
                    .padding(.horizontal)
                    .environmentObject(panelManager)

            }.frame(height: 14).padding(.vertical, 5)

            HStack {
                if let currentPanel = currentPanel {
                    currentPanel.mainView
                        .padding(.horizontal)
                } else {
                    Text("Empty Panel")
                }
            }.frame(maxHeight: .infinity)
        }
        .foregroundColor(Color(id: "panelTitle.activeForeground"))
        .font(.system(size: 12, weight: .light))
    }

}

struct PanelView: View {

    @EnvironmentObject var App: MainApp

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @SceneStorage("panel.visible") var showsPanel: Bool = DefaultUIState.PANEL_IS_VISIBLE
    @SceneStorage("panel.height") var panelHeight: Double = DefaultUIState.PANEL_HEIGHT

    @State var showSheet = false

    var maxHeight: CGFloat {
        windowHeight
            - UIApplication.shared.getSafeArea(edge: .top)
            - UIApplication.shared.getSafeArea(edge: .bottom)
            - TOP_BAR_HEIGHT
            - EDITOR_MINIMUM_HEIGHT
            - BOTTOM_BAR_HEIGHT
    }
    var windowHeight: CGFloat

    func evaluateProposedHeight(proposal: CGFloat) {
        if proposal < PANEL_MINIMUM_HEIGHT {
            showsPanel = false
            panelHeight = DefaultUIState.PANEL_HEIGHT
        } else if proposal > maxHeight {
            panelHeight = maxHeight
        } else {
            panelHeight = proposal
        }
    }

    var body: some View {
        Implementation()
            .frame(height: min(CGFloat(panelHeight), maxHeight))
            .background(Color.init(id: "editor.background"))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let proposedNewHeight = panelHeight - value.translation.height
                        evaluateProposedHeight(proposal: proposedNewHeight)
                    }
            )
    }
}
