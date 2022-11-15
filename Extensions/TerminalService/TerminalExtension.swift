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
            mainView: AnyView(terminalView()),
            toolBarView: nil
        )
        contribution.panel.registerPanel(panel: panel)
    }
}


private struct terminalView: View {
    @EnvironmentObject var App: MainApp
    
    var body: some View {
        if let wv = App.terminalInstance.webView {
            ZStack {
                Button("Clear Console") {
                    App.terminalInstance.reset()
                }.keyboardShortcut("k", modifiers: [.command])

                Button("SIGINT") {
                    App.terminalInstance.sendInterrupt()
                }.keyboardShortcut("c", modifiers: [.control])

                ViewRepresentable(wv)
                    .onTapGesture {
                        App.monacoInstance.executeJavascript(
                            command: "document.getElementById('overlay').focus()")
                    }
                    .onAppear(perform: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            App.terminalInstance.executeScript("fitAddon.fit()")
                        }
                    })
            }
            .foregroundColor(.clear)
            .font(.system(size: 1))
        }else{
            Text("Terminal initialising")
        }
    }
}

