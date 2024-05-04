//
//  TerminalKeyboardToolbar.swift
//  Code
//
//  Created by Ken Chung on 04/05/2024.
//

import SwiftUI

struct TerminalKeyboardToolBar: View {

    @EnvironmentObject var App: MainApp
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State var pasteBoardHasContent = false

    var body: some View {
        HStack(spacing: horizontalSizeClass == .compact ? 8 : 14) {
            Group {
                if UIPasteboard.general.hasStrings || pasteBoardHasContent {
                    Button(
                        action: {
                            if let string = UIPasteboard.general.string {
                                App.terminalInstance.type(text: string)
                            }
                        },
                        label: {
                            Image(systemName: "doc.on.clipboard")
                        })
                }
                Button(
                    action: {
                        App.terminalInstance.type(text: "\t")
                    },
                    label: {
                        Text("↹")
                    })
            }

            Spacer()

            Group {
                Button(
                    action: {
                        App.terminalInstance.moveCursor(codeSequence: "[A")
                    },
                    label: {
                        Image(systemName: "arrow.up")
                    })
                Button(
                    action: {
                        App.terminalInstance.moveCursor(codeSequence: "[B")
                    },
                    label: {
                        Image(systemName: "arrow.down")
                    })
                Button(
                    action: {
                        App.terminalInstance.moveCursor(codeSequence: "[D")
                    },
                    label: {
                        Image(systemName: "arrow.left")
                    })
                Button(
                    action: {
                        App.terminalInstance.moveCursor(codeSequence: "[C")
                    },
                    label: {
                        Image(systemName: "arrow.right")
                    })
                Button(
                    action: {
                        App.terminalInstance.blur()
                    },
                    label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    })
            }

        }
        .foregroundColor(Color.init(id: "activityBar.foreground"))
        .frame(maxWidth: .infinity, maxHeight: horizontalSizeClass == .compact ? 35 : 40)
        .padding(.horizontal, horizontalSizeClass == .compact ? 5 : 10)
        .background(Color.init(id: "activityBar.background"))
        .ignoresSafeArea()
        .onReceive(
            NotificationCenter.default.publisher(for: UIPasteboard.changedNotification),
            perform: { val in
                if UIPasteboard.general.hasStrings {
                    pasteBoardHasContent = true
                } else {
                    pasteBoardHasContent = false
                }
            })
    }
}
