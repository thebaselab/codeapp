//
//  ActivityBar.swift
//  Code
//
//  Created by Ken Chung on 26/11/2022.
//

import SwiftUI

struct ActivityBar: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var stateManager: MainStateManager

    @SceneStorage("sidebar.visible") var isSideBarVisible: Bool = DefaultUIState.SIDEBAR_VISIBLE
    @SceneStorage("sidebar.tab") var currentSideBarTab: SideBarSection = DefaultUIState.SIDEBAR_TAB
    @SceneStorage("panel.visible") var isPanelVisible: Bool = DefaultUIState.PANEL_IS_VISIBLE

    let openConsolePanel: () -> Void

    func openSidePanel(index: SideBarSection) {
        if !isSideBarVisible {
            currentSideBarTab = index
            withAnimation(.easeIn(duration: 0.2)) {
                isSideBarVisible.toggle()
            }
        } else if isSideBarVisible && currentSideBarTab == index {
            withAnimation(.easeIn(duration: 0.2)) {
                isSideBarVisible.toggle()
            }
        } else {
            currentSideBarTab = index
        }
    }

    func openFile() {
        stateManager.showsFilePicker.toggle()
    }

    func openNewFile() {
        stateManager.showsNewFileSheet.toggle()
    }

    func openFolder() {
        self.isSideBarVisible = true
        stateManager.showsDirectoryPicker = true
    }

    var body: some View {
        VStack(spacing: 0) {

            Group {

                ActivityBarItemView(
                    activityBarItem:
                        ActivityBarItem(
                            action: {
                                openSidePanel(index: .explorer)
                            },
                            isActive: currentSideBarTab == .explorer
                                && isSideBarVisible,
                            iconSystemName: "doc.on.doc",
                            title: "Show Explorer",
                            shortcutKey: "e",
                            modifiers: [.command, .shift],
                            useBubble: false,
                            bubbleText: nil,
                            contextMenuItems: [
                                ContextMenuItem(
                                    action: openNewFile, text: "New File",
                                    imageSystemName: "doc.badge.plus"),
                                ContextMenuItem(
                                    action: openFile, text: "Open File",
                                    imageSystemName: "doc"),
                            ]
                                + (App.workSpaceStorage.remoteConnected
                                    ? []
                                    : [
                                        ContextMenuItem(
                                            action: openFolder,
                                            text: "Open Folder",
                                            imageSystemName: "folder.badge.gear"
                                        )
                                    ])
                        ))

                ActivityBarItemView(
                    activityBarItem:
                        ActivityBarItem(
                            action: {
                                openSidePanel(index: .search)
                            },
                            isActive: currentSideBarTab == .search
                                && isSideBarVisible,
                            iconSystemName: "magnifyingglass",
                            title: "Show Search",
                            shortcutKey: "f",
                            modifiers: [.command, .shift],
                            useBubble: false,
                            bubbleText: nil,
                            contextMenuItems: nil
                        ))

                ActivityBarItemView(
                    activityBarItem:
                        ActivityBarItem(
                            action: {
                                openSidePanel(index: .sourceControl)
                            },
                            isActive: currentSideBarTab == .sourceControl
                                && isSideBarVisible,
                            iconSystemName:
                                "point.topleft.down.curvedto.point.bottomright.up",
                            title: "Show Source Control",
                            shortcutKey: "g",
                            modifiers: [.control, .shift],
                            useBubble: !App.gitTracks.isEmpty,
                            bubbleText: "\(App.gitTracks.count)",
                            contextMenuItems: nil
                        ))

                ActivityBarItemView(
                    activityBarItem:
                        ActivityBarItem(
                            action: {
                                openSidePanel(index: .remote)
                            },
                            isActive: currentSideBarTab == .remote
                                && isSideBarVisible,
                            iconSystemName: "rectangle.connected.to.line.below",
                            title: "Remotes",
                            shortcutKey: "r",
                            modifiers: [.command, .shift],
                            useBubble: App.workSpaceStorage.remoteConnected,
                            bubbleText: nil,
                            contextMenuItems: nil
                        ))

                ActivityBarItemView(
                    activityBarItem:
                        ActivityBarItem(
                            action: {
                                openConsolePanel()
                            },
                            isActive: isPanelVisible,
                            iconSystemName: "chevron.left.slash.chevron.right",
                            title: isPanelVisible ? "Hide Panel" : "Show Panel",
                            shortcutKey: "j",
                            modifiers: [.command],
                            useBubble: false,
                            bubbleText: nil,
                            contextMenuItems: nil
                        ))
            }

            ZStack {
                Color.black.opacity(0.001)
                Spacer()
            }.onTapGesture {
                App.monacoInstance.executeJavascript(
                    command: "document.getElementById('overlay').focus()")
                App.terminalInstance.executeScript(
                    "document.getElementById('overlay').focus()")
            }

            ActivityBarItemView(
                activityBarItem:
                    ActivityBarItem(
                        action: {
                            stateManager.showsSettingsSheet.toggle()
                        },
                        isActive: false,
                        iconSystemName: "slider.horizontal.3",
                        title: "User Settings",
                        shortcutKey: ",",
                        modifiers: [.command],
                        useBubble: false,
                        bubbleText: nil,
                        contextMenuItems: nil
                    ))
        }
        .frame(minWidth: 0, maxWidth: 50.0, minHeight: 0, maxHeight: .infinity)
        .background(Color.init(id: "activityBar.background"))
    }
}
