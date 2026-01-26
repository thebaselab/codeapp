//
//  ActivityBar.swift
//  Code
//
//  Created by Ken Chung on 26/11/2022.
//

import SwiftUI

var ACTIVITY_BAR_WIDTH: CGFloat = 50.0

struct PanelToggleButton: View {
    @SceneStorage("panel.visible") var isPanelVisible: Bool = DefaultUIState.PANEL_IS_VISIBLE

    let togglePanel: () -> Void

    var body: some View {
        Button {
            togglePanel()
        } label: {
            ZStack {
                Text(isPanelVisible ? "Hide Panel" : "Show Panel")
                    .foregroundColor(.clear)
                    .font(.system(size: 1))
                Image(systemName: "chevron.left.slash.chevron.right")
                    .font(.system(size: 20, weight: .light))
                    .padding(5)
                    .foregroundColor(
                        Color.init(
                            id: (isPanelVisible)
                                ? "activityBar.foreground"
                                : "activityBar.inactiveForeground")
                    )
            }
        }
        .accessibilityLabel(isPanelVisible ? "Hide Panel" : "Show Panel")
        .keyboardShortcut("j", modifiers: [.command])
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(minWidth: 0, maxWidth: 50.0, minHeight: 0, maxHeight: 60.0)
    }
}

struct ConfigurationToggleButton: View {
    @EnvironmentObject var stateManager: MainStateManager

    var body: some View {
        Button {
            stateManager.showsSettingsSheet.toggle()
        } label: {
            ZStack {
                Text("Settings")
                    .foregroundColor(.clear)
                    .font(.system(size: 1))
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20, weight: .light))
                    .padding(5)
                    .foregroundColor(
                        Color.init("activityBar.inactiveForeground")
                    )
            }
        }
        .keyboardShortcut(",", modifiers: [.command])
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(minWidth: 0, maxWidth: 50.0, minHeight: 0, maxHeight: 60.0)
    }
}

struct ActivityBar: View {
    @EnvironmentObject var App: MainApp
    @EnvironmentObject var stateManager: MainStateManager
    @EnvironmentObject var activityBarManager: ActivityBarManager

    let togglePanel: () -> Void

    var items: [ActivityBarItem] {
        activityBarManager.items
            .sorted { $0.positionPrecedence > $1.positionPrecedence }
            .filter { $0.isVisible() }
    }

    func removeFocus() {
        Task { await App.monacoInstance.blur() }
        App.terminalManager.activeTerminal?.executeScript(
            "document.getElementById('overlay').focus()")
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) {
                ActivityBarIconView(activityBarItem: $0)
            }
            PanelToggleButton(togglePanel: togglePanel)
            ZStack {
                Color.black.opacity(0.001)
                Spacer()
            }.onTapGesture { removeFocus() }
            Spacer()
            ConfigurationToggleButton()
        }
        .frame(minWidth: 0, maxWidth: ACTIVITY_BAR_WIDTH, minHeight: 0, maxHeight: .infinity)
        .background(Color.init(id: "activityBar.background"))
    }
}
