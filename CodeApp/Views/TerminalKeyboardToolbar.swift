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
    @State var controlLocked = false
    @State var controlLastTapTime: Date?
    @State var controlGeneration = 0
    @State var altActive = false
    @State var altLocked = false
    @State var altLastTapTime: Date?
    @State var altGeneration = 0

    private let doubleTapInterval: TimeInterval = 0.3

    private func resetModifierStates() {
        controlActive = false
        controlLocked = false
        App.terminalInstance.setControlActive(false, generation: controlGeneration)
        App.terminalInstance.setControlLocked(false)
        altActive = false
        altLocked = false
        App.terminalInstance.setAltActive(false, generation: altGeneration)
        App.terminalInstance.setAltLocked(false)
    }

    private func resetUnlockedModifiers() {
        // Reset modifiers only if they are not locked
        if !controlLocked {
            controlActive = false
            App.terminalInstance.setControlActive(false, generation: controlGeneration)
        }
        if !altLocked {
            altActive = false
            App.terminalInstance.setAltActive(false, generation: altGeneration)
        }
    }

    private func handleControlTap() {
        let now = Date()
        let isDoubleTap =
            controlLastTapTime.map { now.timeIntervalSince($0) < doubleTapInterval } ?? false
        controlLastTapTime = now

        if controlLocked {
            // Single tap while locked: unlock and deactivate
            controlLocked = false
            controlActive = false
            controlGeneration += 1
            App.terminalInstance.setControlLocked(false)
            App.terminalInstance.setControlActive(false, generation: controlGeneration)
        } else if isDoubleTap && controlActive {
            // Double tap while active: lock
            controlLocked = true
            App.terminalInstance.setControlLocked(true)
        } else {
            // Single tap: toggle active state
            controlActive.toggle()
            controlGeneration += 1
            App.terminalInstance.setControlActive(controlActive, generation: controlGeneration)
        }
    }

    private func handleAltTap() {
        let now = Date()
        let isDoubleTap =
            altLastTapTime.map { now.timeIntervalSince($0) < doubleTapInterval } ?? false
        altLastTapTime = now

        if altLocked {
            // Single tap while locked: unlock and deactivate
            altLocked = false
            altActive = false
            altGeneration += 1
            App.terminalInstance.setAltLocked(false)
            App.terminalInstance.setAltActive(false, generation: altGeneration)
        } else if isDoubleTap && altActive {
            // Double tap while active: lock
            altLocked = true
            App.terminalInstance.setAltLocked(true)
        } else {
            // Single tap: toggle active state
            altActive.toggle()
            altGeneration += 1
            App.terminalInstance.setAltActive(altActive, generation: altGeneration)
        }
    }

    private func typeAndResetModifiers(text: String) {
        App.terminalInstance.type(text: text)
        resetUnlockedModifiers()
    }

    private func moveCursorAndResetModifiers(codeSequence: String) {
        App.terminalInstance.moveCursor(codeSequence: codeSequence)
        resetUnlockedModifiers()
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
                        handleControlTap()
                    },
                    label: {
                        Text("Ctrl")
                            .padding(.horizontal, 4)
                            .background(
                                controlActive ? Color.accentColor.opacity(0.3) : Color.clear
                            )
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.accentColor, lineWidth: controlLocked ? 2 : 0)
                            )
                    }
                )
                .accessibilityLabel("Control")
                .accessibilityValue(
                    controlLocked ? "Locked" : (controlActive ? "Active" : "Inactive"))
                Button(
                    action: {
                        handleAltTap()
                    },
                    label: {
                        Text("Alt")
                            .padding(.horizontal, 4)
                            .background(
                                altActive ? Color.accentColor.opacity(0.3) : Color.clear
                            )
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.accentColor, lineWidth: altLocked ? 2 : 0)
                            )
                    }
                )
                .accessibilityLabel("Alt")
                .accessibilityValue(altLocked ? "Locked" : (altActive ? "Active" : "Inactive"))
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
