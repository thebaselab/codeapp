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
                        App.monacoInstance.executeJavascript(command: "editor.getModel().undo()")
                    },
                    label: {
                        Image(systemName: "arrow.uturn.left")
                    })
                Button(
                    action: {
                        App.monacoInstance.executeJavascript(command: "editor.getModel().redo()")
                    },
                    label: {
                        Image(systemName: "arrow.uturn.right")
                    })
                Button(
                    action: {
                        App.monacoInstance.monacoWebView.evaluateJavaScript(
                            "editor.getModel().getValueInRange(editor.getSelection())",
                            completionHandler: { result, error in
                                if let result = result as? String, !result.isEmpty {
                                    UIPasteboard.general.string = result
                                }
                            })
                    },
                    label: {
                        Image(systemName: "doc.on.doc")
                    })
                if UIPasteboard.general.hasStrings || pasteBoardHasContent {
                    Button(
                        action: {
                            if let string = UIPasteboard.general.string?.base64Encoded() {
                                App.monacoInstance.executeJavascript(
                                    command:
                                        "editor.executeEdits('source',[{identifier: {major: 1, minor: 1}, range: editor.getSelection(), text: decodeURIComponent(escape(window.atob('\(string)'))), forceMoveMarkers: true}])"
                                )
                            }
                        },
                        label: {
                            Image(systemName: "doc.on.clipboard")
                        })
                }
                if needTabKey {
                    Button(
                        action: {
                            App.monacoInstance.executeJavascript(
                                command: "editor.trigger('keyboard', 'type', {text: '\t'})")
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
                            App.monacoInstance.executeJavascript(
                                command: "editor.trigger('keyboard', 'type', {text: '\(char)'})")
                        },
                        label: {
                            Text(char).padding(.horizontal, 2)
                        })
                }
                if horizontalSizeClass != .compact {
                    Button(
                        action: {
                            App.monacoInstance.executeJavascript(
                                command:
                                    "editor.setPosition({lineNumber: editor.getPosition().lineNumber - 1, column: editor.getPosition().column})"
                            )
                        },
                        label: {
                            Image(systemName: "arrow.up")
                        })
                    Button(
                        action: {
                            App.monacoInstance.executeJavascript(
                                command:
                                    "editor.setPosition({lineNumber: editor.getPosition().lineNumber + 1, column: editor.getPosition().column})"
                            )
                            App.monacoInstance.executeJavascript(
                                command: "editor.trigger('', 'selectNextSuggestion')")
                        },
                        label: {
                            Image(systemName: "arrow.down")
                        })
                }

                Button(
                    action: {
                        App.monacoInstance.executeJavascript(
                            command:
                                "editor.setPosition({lineNumber: editor.getPosition().lineNumber, column: editor.getPosition().column - 1})"
                        )
                    },
                    label: {
                        Image(systemName: "arrow.left")
                    })
                Button(
                    action: {
                        App.monacoInstance.executeJavascript(
                            command:
                                "editor.setPosition({lineNumber: editor.getPosition().lineNumber, column: editor.getPosition().column + 1})"
                        )
                    },
                    label: {
                        Image(systemName: "arrow.right")
                    })
                Button(
                    action: {
                        App.monacoInstance.executeJavascript(
                            command: "document.getElementById('overlay').focus()")
                        App.saveCurrentFile()
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
