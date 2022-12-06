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
    @State var keyboardHeight: CGFloat = 0.0

    var maxHeight: CGFloat {
        UIScreen.main.bounds.height
            - UIApplication.shared.getSafeArea(edge: .top)
            - UIApplication.shared.getSafeArea(edge: .bottom)
            - keyboardHeight
            - TOP_BAR_HEIGHT
            - EDITOR_MINIMUM_HEIGHT
            - BOTTOM_BAR_HEIGHT
    }

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
            .frame(height: CGFloat(panelHeight))
            .background(Color.init(id: "editor.background"))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let proposedNewHeight = panelHeight - value.translation.height
                        evaluateProposedHeight(proposal: proposedNewHeight)
                    }
            )
            .onReceive(
                NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            ) { notification in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    evaluateProposedHeight(proposal: panelHeight)
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardDidChangeFrameNotification),
                perform: { notification in
                    if let keyboardSize =
                        (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
                        .cgRectValue
                    {
                        keyboardHeight = keyboardSize.height
                        evaluateProposedHeight(proposal: panelHeight)
                    }
                }
            )
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification),
                perform: { _ in
                    keyboardHeight = 0.0
                }
            )
        //            .onReceive(
        //                NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification),
        //                perform: { notification in
        //                    if let keyboardSize =
        //                        (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
        //                        .cgRectValue
        //                    {
        //                        let keyboardHeight = keyboardSize.height
        //                        let topPadding = UIApplication.shared.getSafeArea(edge: .top)
        //                        let bottomPadding = UIApplication.shared.getSafeArea(edge: .bottom)
        //                        if self.panelHeight
        //                            > (UIScreen.main.bounds.height - (bottomPadding == 0 ? 60 : 0)
        //                                - topPadding - bottomPadding - keyboardHeight)
        //                        {
        //                            DispatchQueue.main.async {
        //                                self.panelHeight =
        //                                    UIScreen.main.bounds.height - (bottomPadding == 0 ? 60 : 0)
        //                                    - topPadding - bottomPadding - keyboardHeight
        //                            }
        //                        }
        //                    }
        //                }
        //            )
    }
}
