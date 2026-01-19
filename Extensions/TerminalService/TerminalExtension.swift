//
//  TerminalExtension.swift
//  Code
//
//  Created by Ken Chung on 15/11/2022.
//

import SwiftUI

class TerminalExtension: CodeAppExtension {
    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {
        let panel = Panel(
            labelId: "TERMINAL",
            mainView: AnyView(MultiTerminalView()),
            toolBarView: AnyView(ToolbarView())
        )
        contribution.panel.registerPanel(panel: panel)
    }
}

private struct ToolbarView: View {
    @EnvironmentObject var App: MainApp

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                App.terminalManager.createTerminal()
            }) {
                Image(systemName: "plus")
            }
            .disabled(!App.terminalManager.canCreateNewTerminal)
            .help("New Terminal")

            Button(
                action: {
                    App.terminalManager.activeTerminal?.sendInterrupt()
                },
                label: {
                    Text("^C")
                }
            ).keyboardShortcut("c", modifiers: [.control])

            Button(
                action: {
                    App.terminalManager.activeTerminal?.reset()
                },
                label: {
                    Image(systemName: "trash")
                }
            ).keyboardShortcut("k", modifiers: [.command])
        }
    }
}

private struct _TerminalView: UIViewRepresentable {
    let terminal: TerminalInstance

    @EnvironmentObject var App: MainApp

    private func injectBarButtons(webView: WebViewBase) {
        let toolbar = UIHostingController(
            rootView: TerminalKeyboardToolBar(terminalId: terminal.id).environmentObject(App))
        toolbar.view.frame = CGRect(
            x: 0, y: 0, width: (webView.bounds.width), height: 40)

        webView.addInputAccessoryView(toolbar: toolbar.view)
    }

    private func removeBarButtons(webView: WebViewBase) {
        webView.addInputAccessoryView(toolbar: UIView.init())
    }

    func makeUIView(context: Context) -> UIView {
        if terminal.options.toolbarEnabled {
            injectBarButtons(webView: terminal.webView)
        }
        return terminal.webView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if terminal.options.toolbarEnabled {
            injectBarButtons(webView: terminal.webView)
        } else {
            removeBarButtons(webView: terminal.webView)
        }
    }
}

private struct MultiTerminalView: View {
    @EnvironmentObject var App: MainApp
    @AppStorage("consoleFontSize") var consoleFontSize: Int = 14

    private func fitTerminalIfReady(_ terminal: TerminalInstance) {
        guard terminal.isReady else { return }
        terminal.executeScript("fitAddon.fit()")
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                ForEach(App.terminalManager.terminals) { terminal in
                    let isActive = terminal.id == App.terminalManager.activeTerminalId
                    _TerminalView(terminal: terminal)
                        .opacity(isActive ? 1 : 0)
                        .allowsHitTesting(isActive)
                        .accessibilityHidden(!isActive)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                let notification = Notification(
                    name: Notification.Name("terminal.focus"),
                    userInfo: ["sceneIdentifier": App.sceneIdentifier]
                )
                NotificationCenter.default.post(notification)
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("editor.focus"),
                    object: nil),
                perform: { _ in
                    App.terminalManager.activeTerminal?.blur()
                }
            )
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("terminal.focus"),
                    object: nil),
                perform: { notification in
                    guard
                        let sceneIdentifier = notification.userInfo?["sceneIdentifier"] as? UUID,
                        sceneIdentifier != App.sceneIdentifier
                    else { return }
                    App.terminalManager.activeTerminal?.blur()
                }
            )
            .onAppear(perform: {
                guard let terminal = App.terminalManager.activeTerminal else { return }
                fitTerminalIfReady(terminal)
            })
            .onChange(of: App.terminalManager.activeTerminalId) { _ in
                guard let terminal = App.terminalManager.activeTerminal else {
                    return
                }
                fitTerminalIfReady(terminal)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .terminalDidInitialize),
                perform: { notification in
                    guard
                        let terminal = notification.object as? TerminalInstance,
                        terminal.id == App.terminalManager.activeTerminalId
                    else { return }
                    fitTerminalIfReady(terminal)
                }
            )

            // Tab bar on the right (only show if more than one terminal)
            if App.terminalManager.terminals.count > 1 {
                TerminalTabBar()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: App.terminalManager.terminals.count > 1)
        .foregroundColor(.clear)
    }
}
