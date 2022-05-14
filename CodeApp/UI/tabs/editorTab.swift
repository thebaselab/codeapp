//
//  editorTab.swift
//  Code
//
//  Created by Ken Chung on 16/5/2021.
//

import SwiftUI

struct editorTab: View {

    @EnvironmentObject var App: MainApp
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @ObservedObject var currentEditor: EditorInstance
    // This is used for force updating the view.
    @State private var lastUpdateTime: Date = Date()

    var isActive: Bool
    var index: Int
    var onOpenEditor: () -> Void
    var onCloseEditor: () -> Void
    var onSaveEditor: () -> Void

    static private func keyForInt(int: Int) -> KeyEquivalent {
        if int < 10 {
            return KeyEquivalent.init(String(int).first!)
        }
        return KeyEquivalent.init("0")
    }

    var body: some View {
        Group {
            if isActive && lastUpdateTime > Date.distantPast {
                HStack(spacing: 4) {
                    fileIcon(url: currentEditor.url, iconSize: 12, type: currentEditor.type)
                    Button(action: {}) {
                        Group {
                            if let url = URL(string: currentEditor.url)?.standardizedFileURL,
                                let status = App.gitTracks[url]
                            {
                                FileDisplayName(
                                    gitStatus: status,
                                    name: editorDisplayName(editor: currentEditor))
                            } else {
                                FileDisplayName(
                                    gitStatus: nil, name: editorDisplayName(editor: currentEditor))
                            }
                            if currentEditor.isDeleted {
                                Text("(deleted)").italic()
                            }
                        }
                        .lineLimit(1)
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(Color.init(id: "tab.activeForeground"))
                    }.keyboardShortcut(editorTab.keyForInt(int: index + 1), modifiers: .command)

                    if currentEditor.currentVersionId == currentEditor.lastSavedVersionId {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                            .foregroundColor(Color.init(id: "tab.activeForeground"))
                            .frame(width: 18, height: 18)
                            .contentShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                            .hoverEffect(.highlight)
                            .onTapGesture {
                                onCloseEditor()
                            }
                    } else {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 7))
                            .foregroundColor(Color.init(id: "tab.activeForeground"))
                            .frame(width: 18, height: 18)
                            .contentShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                            .hoverEffect(.highlight)
                            .onTapGesture {
                                onCloseEditor()
                            }
                    }

                }
                .frame(height: 40)
                .padding(.horizontal, 8)
                .background(Color.init(id: "tab.activeBackground"))
                .cornerRadius(10, corners: [.topLeft, .topRight])
            } else {
                Button(action: { onOpenEditor() }) {
                    HStack(spacing: 4) {
                        fileIcon(url: currentEditor.url, iconSize: 12, type: currentEditor.type)
                        if let url = URL(string: currentEditor.url)?.standardizedFileURL,
                            let status = App.gitTracks[url]
                        {
                            FileDisplayName(
                                gitStatus: status, name: editorDisplayName(editor: currentEditor))
                        } else {
                            Text(editorDisplayName(editor: currentEditor))
                                .lineLimit(1)
                                .font(.subheadline)
                                .foregroundColor(Color.init(id: "tab.inactiveForeground"))
                        }
                        if currentEditor.currentVersionId != currentEditor.lastSavedVersionId {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 7))
                                .foregroundColor(Color.init(id: "tab.inactiveForeground"))
                                .frame(width: 18, height: 18)
                                .contentShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                                .hoverEffect(.highlight)
                                .onTapGesture {
                                    onCloseEditor()
                                }
                        }
                    }
                }.keyboardShortcut(editorTab.keyForInt(int: index + 1), modifiers: .command)
                    .frame(height: 40)
                    .padding(.horizontal, 8)
            }
        }.onTapGesture {
            if !(isActive) {
                onOpenEditor()
            }
        }
    }
}
