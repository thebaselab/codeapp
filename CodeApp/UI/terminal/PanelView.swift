//
//  panel.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI
import ios_system

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
    @SceneStorage("panel.currentSection") var currentSection: String = "PROBLEMS"

    var body: some View {
        Text(panel.labelId)
            .foregroundColor(
                Color.init(
                    id: panel.labelId == currentSection
                        ? "panelTitle.activeForeground" : "panelTitle.inactiveForeground")
            )
            .font(.system(size: 12, weight: .light))
            .padding(.leading)
            .onTapGesture {
                currentSection = panel.labelId
            }
    }
}

struct PanelView: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var panelManager: PanelManager

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @AppStorage("consoleFontSize") var consoleFontSize: Int = 14

    @SceneStorage("panel.visible") var showsPanel: Bool = false
    @SceneStorage("panel.height") var panelHeight: Double = 200.0
    @SceneStorage("panel.splitViewEnabled") var showSplitView: Bool = false
    @SceneStorage("panel.currentSection") var currentSection: String = "PROBLEMS"

    @State var showSheet = false
    @State var keyboardHeight: CGFloat = 0.0

    var currentPanel: Panel? {
        panelManager.panels.first(where: { $0.labelId == currentSection })
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

                Spacer()

                currentPanel?
                    .toolBarView
                    .environmentObject(panelManager)

            }.frame(height: 14).padding(.top, 5).padding(.bottom, 5)

            HStack {
                if let currentPanel = currentPanel {
                    currentPanel.mainView
                        .padding(.horizontal)
                } else {
                    Text("Empty Panel")
                }
            }

            Spacer()
        }
        .frame(height: CGFloat(panelHeight))
        .background(Color.init(id: "editor.background"))
        //            .gesture(
        //                DragGesture()
        //                    .onChanged { value in
        //                        if (self.panelHeight + (value.translation.height) * -1) < 40 {
        //                            self.showsPanel = false
        //                        }
        //                        let topPadding = UIApplication.shared.getSafeArea(edge: .top)
        //                        let bottomPadding = UIApplication.shared.getSafeArea(edge: .bottom)
        //                        if (self.panelHeight + (value.translation.height) * -1)
        //                            < (UIScreen.main.bounds.height - (bottomPadding == 0 ? 60 : 0)
        //                                - topPadding - bottomPadding - keyboardHeight)
        //                        {
        //                            self.panelHeight = self.panelHeight + (value.translation.height) * -1
        //                        } else {
        //                            self.panelHeight =
        //                                UIScreen.main.bounds.height - (bottomPadding == 0 ? 60 : 0)
        //                                - topPadding - bottomPadding - keyboardHeight
        //                        }
        //                    }
        //            )
        //            .onReceive(
        //                NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        //            ) { _ in
        //                let topPadding = UIApplication.shared.getSafeArea(edge: .top)
        //                let bottomPadding = UIApplication.shared.getSafeArea(edge: .bottom)
        //                if self.panelHeight
        //                    > (UIScreen.main.bounds.height - (bottomPadding == 0 ? 60 : 0) - topPadding
        //                        - bottomPadding - keyboardHeight)
        //                {
        //                    self.panelHeight =
        //                        UIScreen.main.bounds.height - (bottomPadding == 0 ? 60 : 0) - topPadding
        //                        - bottomPadding - keyboardHeight
        //                }
        //            }
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
        //            .onReceive(
        //                NotificationCenter.default.publisher(
        //                    for: UIResponder.keyboardDidChangeFrameNotification),
        //                perform: { notification in
        //                    if let keyboardSize =
        //                        (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
        //                        .cgRectValue
        //                    {
        //                        keyboardHeight = keyboardSize.height
        //                    }
        //                }
        //            )
        //            .onReceive(
        //                NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification),
        //                perform: { _ in
        //                    self.keyboardHeight = 0.0
        //                }
        //            )
        //            .onChange(of: consoleFontSize) { value in
        //                App.terminalInstance.setFontSize(size: value)
        //            }
    }
}
