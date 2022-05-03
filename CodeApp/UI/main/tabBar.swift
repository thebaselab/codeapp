//
//  tabBar.swift
//  Code
//
//  Created by Ken Chung on 1/7/2021.
//

import SwiftUI

struct tabBar: View {

    @EnvironmentObject var App: MainApp

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Binding var isShowingDirectory: Bool
    @Binding var showingSettingsSheet: Bool
    @Binding var showSafari: Bool
    let runCode: () -> Void
    let openConsolePanel: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if !isShowingDirectory && horizontalSizeClass == .compact {
                Button(action: {
                    withAnimation(.easeIn(duration: 0.2)) {
                        isShowingDirectory.toggle()
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
            tabs()
            Spacer()

            if App.compileManager.isRunningCode {
                Image(systemName: "stop").font(.system(size: 17)).foregroundColor(Color.init("T1"))
                    .padding(5).frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20)
                    .padding()
                    .onTapGesture {
                        App.compileManager.stopRunning()
                    }
            } else if !App.workSpaceStorage.remoteConnected {
                Button(action: {
                    if !App.currentURL().contains("index{default}.md{code-preview}") {
                        if App.currentURL().components(separatedBy: "/").last?.components(
                            separatedBy: "."
                        ).last == "html" {
                            showSafari.toggle()
                        } else {
                            runCode()
                        }
                    }
                }) {
                    ZStack {
                        Text("Run Code").foregroundColor(.clear).font(.system(size: 1))
                        Image(systemName: "play").font(.system(size: 17)).foregroundColor(
                            Color.init("T1")
                        ).padding(5)
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .hoverEffect(.highlight)
                            .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20)
                    }.padding()

                }.keyboardShortcut("r", modifiers: [.command])
            }

            if App.branch != "" && App.activeEditor?.type == .file {
                Button(action: {
                    if let url = URL(string: App.currentURL()) {
                        App.compareWithPrevious(url: url.standardizedFileURL)
                    }
                }) {
                    Image(systemName: "arrow.2.squarepath").font(.system(size: 17)).foregroundColor(
                        Color.init("T1")
                    ).padding(5)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .hoverEffect(.highlight)
                        .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20)
                        .padding()
                }
            }

            if App.activeEditor?.type == .diff {
                Image(systemName: "arrow.up").font(.system(size: 17)).foregroundColor(
                    Color.init("T1")
                ).padding(5)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .hoverEffect(.highlight)
                    .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20).padding()
                    .onTapGesture {
                        App.monacoInstance.executeJavascript(command: "navi.previous()")
                    }
                Image(systemName: "arrow.down").font(.system(size: 17)).foregroundColor(
                    Color.init("T1")
                ).padding(5)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .hoverEffect(.highlight)
                    .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20).padding()
                    .onTapGesture { App.monacoInstance.executeJavascript(command: "navi.next()") }
            }

            if let ext = App.currentURL().lowercased().components(separatedBy: ".").last,
                ext == "md" || ext == "markdown"
            {
                Image(systemName: "newspaper").font(.system(size: 17)).foregroundColor(
                    Color.init("T1")
                ).padding(5)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .hoverEffect(.highlight)
                    .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20).padding()
                    .onTapGesture {
                        guard let url = URL(string: App.activeEditor?.url ?? ""),
                            let content = App.activeEditor?.content
                        else {
                            return
                        }
                        App.addMarkDownPreview(url: url, content: content)
                    }
            }

            if App.activeEditor?.type == .file || App.activeEditor?.type == .diff {
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
                if App.activeEditor?.type == .diff {
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

                    Button(action: { App.closeAllEditors() }) {
                        Label("Close All", systemImage: "xmark")
                    }
                    if !App.workSpaceStorage.remoteConnected {
                        Button(action: { self.showSafari.toggle() }) {
                            Label("Preview in Safari", systemImage: "safari")
                        }
                    }
                }
                Divider()
                Section {
                    Button(action: {
                        App.openEditor(urlString: "welcome.md{welcome}", type: .preview)
                    }) {
                        Label("Show Welcome Page", systemImage: "newspaper")
                    }

                    Button(action: {
                        openConsolePanel()
                    }) {
                        Label("Show Panel", systemImage: "chevron.left.slash.chevron.right")
                    }

                    Button(action: {
                        showingSettingsSheet.toggle()
                    }) {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 17, weight: .light))
                    .foregroundColor(Color.init("T1")).padding(5)
                    .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .hoverEffect(.highlight)
                    .padding()
            }
            .sheet(isPresented: $showingSettingsSheet) {
                settingView()
                    .environmentObject(App)
            }

        }
    }
}
