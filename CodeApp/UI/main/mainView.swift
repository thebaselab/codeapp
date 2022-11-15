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

struct mainScene: View {
    @StateObject var App = MainApp()
    @StateObject var extensionManager = ExtensionManager()

    var body: some View {
        mainView()
            .environmentObject(App)
            .environmentObject(extensionManager)
            .onAppear {
                extensionManager.initializeExtensions(app: App)
            }
    }
}

private struct mainView: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var extensionManager: ExtensionManager

    @State var showChangeLog: Bool
    @State var showingSettingsSheet: Bool = false
    @State var showingNewFileSheet: Bool = false
    @State var showsDirectoryPicker: Bool = false
    @State var showsFilePicker: Bool = false
    @State var showSafari: Bool = false
    @State var isShowingCheckoutAlert: Bool = false
    @State var selectedBranch: checkoutDest? = nil
    @State var checkoutDetached: Bool = false

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @AppStorage("editorFontSize") var editorTextSize: Int = 14
    @AppStorage("editorReadOnly") var editorReadOnly = false
    @AppStorage("compilerShowPath") var compilerShowPath = false

    @SceneStorage("sidebar.visible") var isShowingDirectory: Bool = false
    @SceneStorage("sidebar.tab") var currentDirectory: Int = 0
    @SceneStorage("panel.height") var panelHeight: Double = 200.0
    @SceneStorage("panel.visible") var showsPanel: Bool = false

    let sections: [Int: [String]] = [
        0: ["Files", "doc.on.doc"], 1: ["Search", "magnifyingglass"],
        3: ["Source Control", "point.topleft.down.curvedto.point.bottomright.up"],
        4: ["Remotes", "rectangle.connected.to.line.below"],
    ]

    init() {
        if let lastReadVersion = UserDefaults.standard.string(forKey: "changelog.lastread") {
            let currentVersion =
                Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
            if lastReadVersion != currentVersion {
                _showChangeLog = State(initialValue: true)
                UserDefaults.standard.setValue(currentVersion, forKey: "changelog.lastread")
                return
            } else {
                _showChangeLog = State(initialValue: false)
            }
        } else {
            let currentVersion =
                Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
            UserDefaults.standard.setValue(currentVersion, forKey: "changelog.lastread")
            _showChangeLog = State(initialValue: true)
            return
        }
    }

    func openFolder() {
        self.isShowingDirectory = true
        self.showsDirectoryPicker = true
    }

    func openFile() {
        self.showsFilePicker.toggle()
    }

    func openNewFile() {
        self.showingNewFileSheet.toggle()
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

    func runCode() {
        //                guard let editor = App.activeEditor else {
        //                    return
        //                }
        //                App.runCode(url: editor.url, lang: App.compilerCode)
        //                DispatchQueue.main.async {
        //                    if self.panelHeight < 70 {
        //                        self.panelHeight = 200
        //                    }
        //                    self.showsPanel = true
        //                    if App.compilerCode < 10 {
        //                        self.currentPanelTab = PanelSection.terminal
        //                    } else {
        //                        self.currentPanelTab = PanelSection.remoteExecutionOutput
        //                    }
        //
        //                }
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
                                                showingSettingsSheet.toggle()
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
                                        ExplorerContainer(
                                            showingNewFileSheet: $showingNewFileSheet,
                                            showsDirectoryPicker: $showsDirectoryPicker)
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
                                tabBar(
                                    isShowingDirectory: $isShowingDirectory,
                                    showingSettingsSheet: $showingSettingsSheet,
                                    showSafari: $showSafari, runCode: runCode,
                                    openConsolePanel: openConsolePanel
                                )
                                .environmentObject(extensionManager.toolbarManager)
                                .frame(height: 40)

                                editorView(
                                    showsNewFile: $showingNewFileSheet,
                                    showsDirectory: $isShowingDirectory,
                                    showsFolderPicker: $showsDirectoryPicker,
                                    showsFilePicker: $showsFilePicker,
                                    directoryID: $currentDirectory
                                )
                                .disabled(horizontalSizeClass == .compact && isShowingDirectory)
                                .sheet(isPresented: $showingNewFileSheet) {
                                    newFileView(
                                        targetUrl: App.workSpaceStorage.currentDirectory.url
                                    ).environmentObject(App)
                                }

                                if showsPanel {
                                    PanelView()
                                        .environmentObject(extensionManager.panelManager)
                                }
                            }
                            .edgesIgnoringSafeArea(.bottom)
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
                                            }.sheet(isPresented: $showingNewFileSheet) {
                                                newFileView(
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
                                                ExplorerContainer(
                                                    showingNewFileSheet: $showingNewFileSheet,
                                                    showsDirectoryPicker: $showsDirectoryPicker)
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
                    bottomBar(
                        showChangeLog: showChangeLog,
                        showingNewFileSheet: $showingNewFileSheet,
                        showSafari: $showSafari,
                        showsFilePicker: $showsFilePicker,
                        showsDirectoryPicker: $showsDirectoryPicker,
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
        }.hiddenScrollableContentBackground()
    }
}
