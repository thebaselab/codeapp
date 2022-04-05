//
//  terminalToolBar.swift
//  Code App
//
//  Created by Ken Chung on 25/2/2021.
//

import SwiftUI
import WebKit

struct terminalToolBar: View {

    var evaluateScript: ((String) -> Void)
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

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
        HStack {
            Group {
                Button(
                    action: {

                        evaluateScript("editor.getModel().undo()")
                    },
                    label: {
                        Image(systemName: "arrow.uturn.left")
                    })
                Button(
                    action: {
                        evaluateScript("editor.getModel().redo()")
                    },
                    label: {
                        Image(systemName: "arrow.uturn.right")
                    })
                if UIPasteboard.general.hasStrings {
                    Button(
                        action: {
                            if let string = UIPasteboard.general.string?.base64Encoded() {
                                evaluateScript(
                                    "editor.trigger('keyboard', 'type', {text: decodeURIComponent(escape(window.atob('\(string)')))})"
                                )
                            }
                        },
                        label: {
                            Image(systemName: "doc.on.clipboard")
                        })
                }
                Button(
                    action: {
                        evaluateScript("editor.trigger('', 'editor.action.quickCommand')")
                    },
                    label: {
                        Image(systemName: "terminal")
                    })

                if needTabKey {
                    Button(
                        action: {
                            evaluateScript("editor.trigger('keyboard', 'type', {text: '\t'})")
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
                            evaluateScript("editor.trigger('keyboard', 'type', {text: '\(char)'})")
                        },
                        label: {
                            Text(char).padding(.horizontal, 2)
                        })
                }

                Button(
                    action: {
                        evaluateScript(
                            "editor.setPosition({lineNumber: editor.getPosition().lineNumber - 1, column: editor.getPosition().column})"
                        )
                    },
                    label: {
                        Image(systemName: "arrow.up")
                    })
                Button(
                    action: {
                        evaluateScript(
                            "editor.setPosition({lineNumber: editor.getPosition().lineNumber + 1, column: editor.getPosition().column})"
                        )
                        evaluateScript("editor.trigger('', 'selectNextSuggestion')")
                    },
                    label: {
                        Image(systemName: "arrow.down")
                    })
                Button(
                    action: {
                        evaluateScript(
                            "editor.setPosition({lineNumber: editor.getPosition().lineNumber, column: editor.getPosition().column - 1})"
                        )
                    },
                    label: {
                        Image(systemName: "arrow.left")
                    })
                Button(
                    action: {
                        evaluateScript(
                            "editor.setPosition({lineNumber: editor.getPosition().lineNumber, column: editor.getPosition().column + 1})"
                        )
                    },
                    label: {
                        Image(systemName: "arrow.right")
                    })
            }

        }
        .foregroundColor(Color.init("BW"))
        .frame(maxWidth: .infinity, maxHeight: horizontalSizeClass == .compact ? 35 : 40)
        .padding(.horizontal, horizontalSizeClass == .compact ? 5 : 10)
        .background(Color.init("tab.activeBackground"))
    }
}
