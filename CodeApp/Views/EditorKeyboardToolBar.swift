//
//  keyboardToolBar.swift
//  Code App
//
//  Created by Ken Chung on 4/2/2021.
//

import SwiftUI

struct EditorKeyboardToolBar: View {

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State var pasteBoardHasContent = false
    var editorImplementation: EditorImplementation
    var isMonaco: Bool { editorImplementation is MonacoImplementation }

    var body: some View {
        HStack(spacing: horizontalSizeClass == .compact ? 8 : 14) {
            Group {
                Button(
                    action: {
                        Task { await editorImplementation.undo() }
                    },
                    label: {
                        Image(systemName: "arrow.uturn.left")
                    })
                Button(
                    action: {
                        Task { await editorImplementation.redo() }
                    },
                    label: {
                        Image(systemName: "arrow.uturn.right")
                    })
                if isMonaco {
                    Button(
                        action: {
                            Task {
                                let selected = await editorImplementation.getSelectedValue()
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
                                        await editorImplementation.pasteText(text: string)
                                    }
                                }
                            },
                            label: {
                                Image(systemName: "doc.on.clipboard")
                            })
                    }
                }

                Button(
                    action: {
                        Task {
                            await editorImplementation.pasteText(text: "\t")
                        }
                    },
                    label: {
                        Text("↹")
                    })
            }

            Spacer()

            Group {
                ForEach(["{", "}", "[", "]", "(", ")"], id: \.self) { char in
                    Button(
                        action: {
                            Task {
                                await editorImplementation.pasteText(text: char)
                            }
                        },
                        label: {
                            Text(char).padding(.horizontal, 2)
                        })
                }
                if isMonaco {
                    if horizontalSizeClass != .compact {
                        Button(
                            action: {
                                Task {
                                    await editorImplementation.moveCursor(direction: .up)
                                }
                            },
                            label: {
                                Image(systemName: "arrow.up")
                            })
                        Button(
                            action: {
                                Task {
                                    await editorImplementation.moveCursor(direction: .down)
                                }
                            },
                            label: {
                                Image(systemName: "arrow.down")
                            })
                    }

                    Button(
                        action: {
                            Task {
                                await editorImplementation.moveCursor(direction: .left)
                            }
                        },
                        label: {
                            Image(systemName: "arrow.left")
                        })
                    Button(
                        action: {
                            Task {
                                await editorImplementation.moveCursor(direction: .right)
                            }
                        },
                        label: {
                            Image(systemName: "arrow.right")
                        })
                }

                Button(
                    action: {
                        Task {
                            await editorImplementation.blur()
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
