//
//  keyboardToolBar.swift
//  Code App
//
//  Created by Ken Chung on 4/2/2021.
//

import GameController
import SwiftUI

struct EditorKeyboardToolBar: View {

    @EnvironmentObject var App: MainApp
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State var pasteBoardHasContent = false

    var needTabKey: Bool {
        let deviceModel = UIDevice.current.model
        if !deviceModel.hasPrefix("iPad") { return true }  // iPhone, iPod: minimalist keyboard.
        if deviceModel.hasPrefix("iPad6") {
            if (deviceModel == "iPad6,7") || (deviceModel == "iPad6,8") {
                return false  // iPad Pro 12.9" 1st gen
            } else {
                return true
            }
        }
        if deviceModel.hasPrefix("iPad7") {
            if (deviceModel == "iPad7,1") || (deviceModel == "iPad7,2") {
                return false  // iPad Pro 12.9" 2nd gen
            } else {
                return true
            }
        }
        if deviceModel.hasPrefix("iPad8") {
            return false  // iPad Pro 11" or iPad Pro 12.9" 3rd gen
        }
        return true  // All other iPad models.
    }

    var body: some View {
        HStack(spacing: horizontalSizeClass == .compact ? 8 : 14) {
            Group {
                Button(
                    action: {
                        Task { await App.monacoInstance.undo() }
                    },
                    label: {
                        Image(systemName: "arrow.uturn.left")
                    })
                Button(
                    action: {
                        Task { await App.monacoInstance.redo() }
                    },
                    label: {
                        Image(systemName: "arrow.uturn.right")
                    })
                Button(
                    action: {
                        Task {
                            let selected = await App.monacoInstance.getSelectedValue()
                            UIPasteboard.general.string = selected
                        }
                    },
                    label: {
                        Image(systemName: "doc.on.doc")
                    })
                if UIPasteboard.general.hasStrings || pasteBoardHasContent {
                    Button(
                        action: {
                            if let string = UIPasteboard.general.string {
                                Task {
                                    await App.monacoInstance.pasteText(text: string)
                                }
                            }
                        },
                        label: {
                            Image(systemName: "doc.on.clipboard")
                        })
                }
                if needTabKey {
                    Button(
                        action: {
                            Task {
                                await App.monacoInstance.pasteText(text: "\t")
                            }
                        },
                        label: {
                            Text("↹")
                        })
                }

            }

            Spacer()

            Group {
                ForEach(["{", "}", "[", "]", "(", ")"], id: \.self) { char in
                    Button(
                        action: {
                            Task {
                                await App.monacoInstance.pasteText(text: char)
                            }
                        },
                        label: {
                            Text(char).padding(.horizontal, 2)
                        })
                }
                if horizontalSizeClass != .compact {
                    Button(
                        action: {
                            Task {
                                await App.monacoInstance.moveCursor(direction: .up)
                            }
                        },
                        label: {
                            Image(systemName: "arrow.up")
                        })
                    Button(
                        action: {
                            Task {
                                await App.monacoInstance.moveCursor(direction: .down)
                            }
                        },
                        label: {
                            Image(systemName: "arrow.down")
                        })
                }

                Button(
                    action: {
                        Task {
                            await App.monacoInstance.moveCursor(direction: .left)
                        }
                    },
                    label: {
                        Image(systemName: "arrow.left")
                    })
                Button(
                    action: {
                        Task {
                            await App.monacoInstance.moveCursor(direction: .right)
                        }
                    },
                    label: {
                        Image(systemName: "arrow.right")
                    })
                Button(
                    action: {
                        Task {
                            await App.monacoInstance.blur()
                            await App.saveCurrentFile()
                        }
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
