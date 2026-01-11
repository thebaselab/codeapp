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
    @State var controlActive = false
    @State var controlGeneration = 0
    @State var altActive = false
    @State var altGeneration = 0

    private func resetModifierStates() {
        controlActive = false
        App.terminalInstance.setControlActive(false, generation: controlGeneration)
        altActive = false
        App.terminalInstance.setAltActive(false, generation: altGeneration)
    }

    private func typeAndResetModifiers(text: String) {
        App.terminalInstance.type(text: text)
        resetModifierStates()
    }

    private func moveCursorAndResetModifiers(codeSequence: String) {
        App.terminalInstance.moveCursor(codeSequence: codeSequence)
        resetModifierStates()
    }

    var body: some View {
        HStack(spacing: horizontalSizeClass == .compact ? 8 : 14) {
            Group {
                if UIPasteboard.general.hasStrings || pasteBoardHasContent {
                    Button(
                        action: {
                            if let string = UIPasteboard.general.string {
                                typeAndResetModifiers(text: string)
                            }
                        },
                        label: {
                            Image(systemName: "doc.on.clipboard")
                        })
                }
                Button(
                    action: {
                        typeAndResetModifiers(text: "\u{1b}")
                    },
                    label: {
                        Text("Esc")
                    }
                )
                .accessibilityLabel("Escape")
                Button(
                    action: {
                        typeAndResetModifiers(text: "\t")
                    },
                    label: {
                        Text("↹")
                    })
                Button(
                    action: {
                        controlActive.toggle()
                        controlGeneration += 1
                        App.terminalInstance.setControlActive(
                            controlActive, generation: controlGeneration)
                    },
                    label: {
                        Text("Ctrl")
                            .padding(.horizontal, 4)
                            .background(
                                controlActive ? Color.accentColor.opacity(0.3) : Color.clear
                            )
                            .cornerRadius(4)
                    }
                )
                .accessibilityLabel("Control")
                .accessibilityValue(controlActive ? "Active" : "Inactive")
                Button(
                    action: {
                        altActive.toggle()
                        altGeneration += 1
                        App.terminalInstance.setAltActive(
                            altActive, generation: altGeneration)
                    },
                    label: {
                        Text("Alt")
                            .padding(.horizontal, 4)
                            .background(
                                altActive ? Color.accentColor.opacity(0.3) : Color.clear
                            )
                            .cornerRadius(4)
                    }
                )
                .accessibilityLabel("Alt")
                .accessibilityValue(altActive ? "Active" : "Inactive")
                Button(
                    action: {
                        typeAndResetModifiers(text: "\u{1b}[3~")
                    },
                    label: {
                        Text("Del")
                    }
                )
                .accessibilityLabel("Delete")
            }

            Spacer()

            Group {
                Button(
                    action: {
                        moveCursorAndResetModifiers(codeSequence: "[A")
                    },
                    label: {
                        Image(systemName: "arrow.up")
                    })
                Button(
                    action: {
                        moveCursorAndResetModifiers(codeSequence: "[B")
                    },
                    label: {
                        Image(systemName: "arrow.down")
                    })
                Button(
                    action: {
                        moveCursorAndResetModifiers(codeSequence: "[D")
                    },
                    label: {
                        Image(systemName: "arrow.left")
                    })
                Button(
                    action: {
                        moveCursorAndResetModifiers(codeSequence: "[C")
                    },
                    label: {
                        Image(systemName: "arrow.right")
                    })
                Button(
                    action: {
                        resetModifierStates()
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
            perform: { _ in
                if UIPasteboard.general.hasStrings {
                    pasteBoardHasContent = true
                } else {
                    pasteBoardHasContent = false
                }
            }
        )
        .onReceive(
            NotificationCenter.default.publisher(
                for: .terminalControlReset,
                object: App.terminalInstance
            ),
            perform: { notification in
                if let generation = notification.userInfo?["generation"] as? Int,
                    generation == controlGeneration
                {
                    controlActive = false
                }
            }
        )
        .onReceive(
            NotificationCenter.default.publisher(
                for: .terminalAltReset,
                object: App.terminalInstance
            ),
            perform: { notification in
                if let generation = notification.userInfo?["generation"] as? Int,
                    generation == altGeneration
                {
                    altActive = false
                }
            })
    }
}
