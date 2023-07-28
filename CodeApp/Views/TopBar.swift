//
//  tabBar.swift
//  Code
//
//  Created by Ken Chung on 1/7/2021.
//

import SwiftUI

struct TopBar: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var toolBarManager: ToolbarManager
    @EnvironmentObject var stateManager: MainStateManager

    @SceneStorage("sidebar.visible") var isSideBarExpanded: Bool = DefaultUIState.SIDEBAR_VISIBLE
    @SceneStorage("panel.visible") var isPanelVisible: Bool = DefaultUIState.PANEL_IS_VISIBLE

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let openConsolePanel: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if !isSideBarExpanded && horizontalSizeClass == .compact {
                Button(action: {
                    withAnimation(.easeIn(duration: 0.2)) {
                        isSideBarExpanded.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 17))
                        .foregroundColor(Color.init("T1"))
                        .padding(5)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .hoverEffect(.highlight)
                        .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20)
                        .padding()
                }
            }

            if horizontalSizeClass == .compact {
                CompactEditorTabs()
                    .frame(maxWidth: .infinity)
            } else {
                EditorTabs()
                Spacer()
            }

            ForEach(toolBarManager.items) { item in
                if item.shouldDisplay() {
                    ToolbarItemView(item: item)
                }
            }

            if App.activeTextEditor != nil {
                Image(systemName: "doc.text.magnifyingglass").font(.system(size: 17))
                    .foregroundColor(Color.init("T1")).padding(5)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .hoverEffect(.highlight)
                    .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20).padding()
                    .onTapGesture {
                        App.monacoInstance.executeJavascript(command: "editor.focus()")
                        App.monacoInstance.executeJavascript(
                            command: "editor.getAction('actions.find').run()")
                    }
            }

            Menu {
                if App.activeTextEditor is DiffTextEditorInstnace {
                    Section {
                        Button(action: {
                            App.monacoInstance.applyOptions(options: "renderSideBySide: false")
                        }) {
                            Label(
                                NSLocalizedString("Toogle Inline View", comment: ""),
                                systemImage: "doc.text")
                        }
                    }
                }
                Section {
                    Button(role: .destructive) {
                        App.closeAllEditors()
                    } label: {
                        Label("Close All", systemImage: "xmark")
                    }
                    Button(role: .destructive) {
                        App.loadFolder(url: getRootDirectory())
                        DispatchQueue.main.async {
                            App.showWelcomeMessage()
                        }
                    } label: {
                        Label("Close Workspace", systemImage: "xmark")
                    }
                }
                Divider()
                Section {
                    Button(action: {
                        App.showWelcomeMessage()
                    }) {
                        Label("Show Welcome Page", systemImage: "newspaper")
                    }

                    Button(action: {
                        openConsolePanel()
                    }) {
                        Label(
                            isPanelVisible ? "Hide Panel" : "Show Panel",
                            systemImage: "chevron.left.slash.chevron.right")
                    }.keyboardShortcut("j", modifiers: .command)

                    if UIApplication.shared.supportsMultipleScenes {
                        Button(action: {
                            UIApplication.shared.requestSceneSessionActivation(
                                nil, userActivity: nil, options: nil, errorHandler: nil)
                        }) {
                            Label("actions.new_window", systemImage: "square.split.2x1")
                        }
                    }

                    Button(action: {
                        stateManager.showsSettingsSheet.toggle()
                    }) {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                }

                #if DEBUG
                    DebugMenu()
                #endif

            } label: {
                Image(systemName: "ellipsis").font(.system(size: 17, weight: .light))
                    .foregroundColor(Color.init("T1")).padding(5)
                    .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .hoverEffect(.highlight)
                    .padding()
            }
            .sheet(isPresented: $stateManager.showsSettingsSheet) {
                SettingsView()
                    .environmentObject(App)
            }

        }
    }
}

private struct StackedImageIconView: View {

    var primaryIcon: String
    var secondaryIcon: String?

    var body: some View {
        Image(systemName: primaryIcon)
            .font(.system(size: 17))
            .overlay(alignment: .bottomTrailing) {
                if let secondaryIcon {
                    Image(systemName: secondaryIcon)
                        .foregroundStyle(.background, Color.init("T1"))
                        .font(.system(size: 9))
                } else {
                    EmptyView()
                }
            }

    }
}

private struct ToolbarItemView: View {

    @SceneStorage("panel.visible") var showsPanel: Bool = DefaultUIState.PANEL_IS_VISIBLE
    @SceneStorage("panel.focusedId") var currentPanel: String = DefaultUIState.PANEL_FOCUSED_ID

    let item: ToolbarItem

    var body: some View {
        Button(action: {
            if let panelToFocus = item.panelToFocusOnTap {
                showsPanel = true
                currentPanel = panelToFocus
            }
            item.onClick()
        }) {
            StackedImageIconView(primaryIcon: item.icon, secondaryIcon: item.secondaryIcon)
                .font(.system(size: 17))
                .foregroundColor(Color.init("T1"))
                .padding(5)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .hoverEffect(.highlight)
                .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20)
                .padding()
        }
        .if(item.shortCut != nil) {
            $0.keyboardShortcut(item.shortCut!.key, modifiers: item.shortCut!.modifiers)
        }
    }
}
