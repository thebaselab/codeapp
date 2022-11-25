//
//  main.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import CoreSpotlight
import SwiftUI
import UIKit
import ios_system

struct MainScene: View {
    @StateObject var App = MainApp()

    @AppStorage("stateRestorationEnabled") var stateRestorationEnabled = true
    @SceneStorage("root.bookmark") var rootDirectoryBookmark: Data?
    @SceneStorage("openEditors.bookmarks") var openEditorsBookmarksData: Data?
    @SceneStorage("activeEditor.bookmark") var activeEditorBookmark: Data?
    @SceneStorage("activeEditor.monaco.state") var activeEditorMonacoState: String?

    func getOpenEditorsBookmarks() -> [Data] {
        guard let openEditorsBookmarksData else { return [] }
        return try! PropertyListDecoder().decode([Data].self, from: openEditorsBookmarksData)
    }

    func setOpenEditorsBookmarks(_ v: [Data]) {
        openEditorsBookmarksData = try? PropertyListEncoder().encode(v)
    }

    func saveSceneState() {
        guard stateRestorationEnabled else { return }
        guard let rootDir = App.workSpaceStorage.currentDirectory._url,
            rootDir.isFileURL,
            let rootDirBookmarkData = try? rootDir.bookmarkData()
        else {
            return
        }
        rootDirectoryBookmark = rootDirBookmarkData
        setOpenEditorsBookmarks(App.editorsWithURL.compactMap { try? $0.url.bookmarkData() })

        if let activeEditor = App.activeTextEditor,
            let activeEditorBookmarkData = try? activeEditor.url.bookmarkData()
        {
            activeEditorBookmark = activeEditorBookmarkData
            App.monacoInstance.monacoWebView.evaluateJavaScript(
                "JSON.stringify(editor.saveViewState())"
            ) {
                res, err in
                if let res = res as? String {
                    activeEditorMonacoState = res
                }
            }
        } else {
            activeEditorBookmark = nil
            activeEditorMonacoState = nil
        }
    }

    func restoreSceneState() {

        var isStale = false

        guard stateRestorationEnabled else { return }
        guard let rootDirBookmark = rootDirectoryBookmark,
            let rootDir = try? URL(
                resolvingBookmarkData: rootDirBookmark, bookmarkDataIsStale: &isStale)
        else {
            return
        }
        App.loadFolder(url: rootDir)

        let editors = getOpenEditorsBookmarks().compactMap {
            try? URL(resolvingBookmarkData: $0, bookmarkDataIsStale: &isStale)
        }
        for editor in editors {
            App.openFile(url: editor, alwaysInNewTab: true)
        }

        if let activeEditorBookmark = activeEditorBookmark,
            let activeEditor = try? URL(
                resolvingBookmarkData: activeEditorBookmark, bookmarkDataIsStale: &isStale)
        {
            App.openFile(url: activeEditor)
        }

    }

    var body: some View {
        MainView()
            .environmentObject(App)
            .environmentObject(App.extensionManager)
            .environmentObject(App.stateManager)
            .onAppear {
                restoreSceneState()
                App.extensionManager.initializeExtensions(app: App)
            }
            .onOpenURL { url in
                _ = url.startAccessingSecurityScopedResource()
                App.openFile(url: url.standardizedFileURL)
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.willResignActiveNotification)
            ) { _ in
                saveSceneState()
            }
    }
}

private struct MainView: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var extensionManager: ExtensionManager
    @EnvironmentObject var stateManager: MainStateManager

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @AppStorage("editorFontSize") var editorTextSize: Int = 14
    @AppStorage("editorReadOnly") var editorReadOnly = false
    @AppStorage("compilerShowPath") var compilerShowPath = false
    @AppStorage("changelog.lastread") var changeLogLastReadVersion = "0.0"

    @SceneStorage("sidebar.visible") var isShowingDirectory: Bool = false
    @SceneStorage("sidebar.tab") var currentDirectory: Int = 0
    @SceneStorage("panel.height") var panelHeight: Double = 200.0
    @SceneStorage("panel.visible") var showsPanel: Bool = DefaultUIState.PANEL_IS_VISIBLE

    let sections: [Int: [String]] = [
        0: ["Files", "doc.on.doc"], 1: ["Search", "magnifyingglass"],
        3: ["source_control.title", "point.topleft.down.curvedto.point.bottomright.up"],
        4: ["Remotes", "rectangle.connected.to.line.below"],
    ]

    func openFolder() {
        self.isShowingDirectory = true
        stateManager.showsDirectoryPicker = true
    }

    func openFile() {
        stateManager.showsFilePicker.toggle()
    }

    func openNewFile() {
        stateManager.showsNewFileSheet.toggle()
    }

    func openConsolePanel() {
        if self.panelHeight < 70 {
            self.panelHeight = 200
        }
        self.showsPanel.toggle()
        App.terminalInstance.webView?.becomeFirstResponder()
    }

    func openSidePanel(index: Int) {
        if !isShowingDirectory {
            currentDirectory = index
            withAnimation(.easeIn(duration: 0.2)) {
                isShowingDirectory.toggle()
            }
        } else if isShowingDirectory && currentDirectory == index {
            withAnimation(.easeIn(duration: 0.2)) {
                isShowingDirectory.toggle()
            }
        } else {
            currentDirectory = index
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        if horizontalSizeClass == .regular {
                            VStack(spacing: 0) {

                                Group {

                                    ActivityBarItemView(
                                        activityBarItem:
                                            ActivityBarItem(
                                                action: {
                                                    openSidePanel(index: 0)
                                                },
                                                isActive: currentDirectory == 0
                                                    && isShowingDirectory,
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
                                                    openSidePanel(index: 1)
                                                },
                                                isActive: currentDirectory == 1
                                                    && isShowingDirectory,
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
                                                    openSidePanel(index: 3)
                                                },
                                                isActive: currentDirectory == 3
                                                    && isShowingDirectory,
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
                                                    openSidePanel(index: 4)
                                                },
                                                isActive: currentDirectory == 4
                                                    && isShowingDirectory,
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
                                                isActive: showsPanel,
                                                iconSystemName: "chevron.left.slash.chevron.right",
                                                title: "Show Panel",
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

                        if isShowingDirectory && horizontalSizeClass == .regular {
                            ZStack(alignment: .topLeading) {

                                Group {
                                    if self.currentDirectory == 0 {
                                        ExplorerContainer()
                                    } else if self.currentDirectory == 1 {
                                        SearchContainer()
                                    } else if self.currentDirectory == 3 {
                                        SourceControlContainer()
                                    } else if self.currentDirectory == 4 {
                                        RemoteContainer()
                                    }
                                }.background(Color.init(id: "sideBar.background"))

                            }.frame(width: 280.0, height: geometry.size.height - 20).background(
                                Color.init(id: "sideBar.background"))
                        }

                        ZStack {
                            VStack(spacing: 0) {
                                TopBar(openConsolePanel: openConsolePanel)
                                    .environmentObject(extensionManager.toolbarManager)
                                    .frame(height: 40)

                                EditorView()
                                    .disabled(horizontalSizeClass == .compact && isShowingDirectory)
                                    .sheet(isPresented: $stateManager.showsNewFileSheet) {
                                        NewFileView(
                                            targetUrl: App.workSpaceStorage.currentDirectory.url
                                        ).environmentObject(App)
                                    }
                                    .environmentObject(extensionManager.editorProviderManager)

                                if showsPanel {
                                    PanelView()
                                        .environmentObject(extensionManager.panelManager)
                                }
                            }
                            .blur(
                                radius: (horizontalSizeClass == .compact && isShowingDirectory)
                                    ? 10 : 0)

                            if isShowingDirectory && horizontalSizeClass == .compact {
                                HStack(spacing: 0) {
                                    VStack {
                                        HStack {
                                            Button(action: {
                                                withAnimation(.easeIn(duration: 0.2)) {
                                                    isShowingDirectory.toggle()
                                                }
                                            }) {
                                                Image(systemName: "sidebar.left")
                                                    .font(.system(size: 17))
                                                    .foregroundColor(Color.init("T1"))
                                                    .padding(5)
                                                    .contentShape(
                                                        RoundedRectangle(
                                                            cornerRadius: 8, style: .continuous)
                                                    )
                                                    .hoverEffect(.highlight)
                                                    .frame(
                                                        minWidth: 0, maxWidth: 20, minHeight: 0,
                                                        maxHeight: 20
                                                    )
                                                    .padding()
                                            }.sheet(isPresented: $stateManager.showsNewFileSheet) {
                                                NewFileView(
                                                    targetUrl: App.workSpaceStorage
                                                        .currentDirectory.url
                                                ).environmentObject(App)
                                            }
                                            Spacer()
                                            Menu {
                                                Picker(
                                                    selection: $currentDirectory,
                                                    label: Text("Section")
                                                ) {
                                                    ForEach([0, 1, 3, 4], id: \.self) { value in
                                                        Label(
                                                            sections[value]![0],
                                                            systemImage: sections[value]![1])
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis.circle")
                                                    .font(.system(size: 17))
                                                    .foregroundColor(Color.init("T1"))
                                                    .padding(5)
                                                    .contentShape(
                                                        RoundedRectangle(
                                                            cornerRadius: 8, style: .continuous)
                                                    )
                                                    .hoverEffect(.highlight)
                                                    .frame(
                                                        minWidth: 0, maxWidth: 20, minHeight: 0,
                                                        maxHeight: 20
                                                    )
                                                    .padding()
                                            }
                                        }
                                        .background(
                                            Color.init(id: "sideBar.background")
                                                .ignoresSafeArea(.container, edges: .top)
                                        )
                                        .frame(height: 40)

                                        Group {
                                            if self.currentDirectory == 0 {
                                                ExplorerContainer()
                                            } else if self.currentDirectory == 1 {
                                                SearchContainer()
                                            } else if self.currentDirectory == 3 {
                                                SourceControlContainer()
                                            } else if self.currentDirectory == 4 {
                                                RemoteContainer()
                                            }
                                        }.background(Color.init(id: "sideBar.background"))

                                    }
                                    .frame(width: 280.0, height: geometry.size.height - 20)
                                    .background(Color.init(id: "sideBar.background"))

                                    ZStack {
                                        Color.black.opacity(0.001)
                                        Spacer()
                                    }.onTapGesture {
                                        withAnimation(.easeIn(duration: 0.2)) {
                                            isShowingDirectory.toggle()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    BottomBar(
                        openConsolePanel: openConsolePanel,
                        onDirectoryPickerFinished: {
                            currentDirectory = 0
                            isShowingDirectory = true
                        }
                    )
                    .frame(width: geometry.size.width, height: 20)
                }

                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        NotificationCentreView().padding(
                            .trailing, (self.horizontalSizeClass == .compact ? 40 : 10))
                    }
                }.padding(.bottom, 30).frame(width: geometry.size.width)

            }
            .background(Color.init(id: "sideBar.background").edgesIgnoringSafeArea(.all))
            .accentColor(Color.init(id: "activityBar.inactiveForeground"))
            .navigationTitle(
                URL(string: App.workSpaceStorage.currentDirectory.url)?.lastPathComponent ?? ""
            )
            .onChange(of: colorScheme) { newValue in
                App.updateView()
            }
            .environmentObject(App)
        }
        .hiddenScrollableContentBackground()
        .onAppear {
            let appVersion =
                Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"

            if changeLogLastReadVersion != appVersion {
                stateManager.showsChangeLog.toggle()
            }

            changeLogLastReadVersion = appVersion
        }
    }
}
