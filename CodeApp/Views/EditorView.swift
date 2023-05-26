//
//  editor.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import AVFoundation
import AVKit
import GameController
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct EditorView: View {
    @EnvironmentObject var App: MainApp
    @EnvironmentObject var preivewProviderManager: EditorProviderManager
    @EnvironmentObject var stateManager: MainStateManager

    @AppStorage("editorLightTheme") var editorLightTheme: String = "Default"
    @AppStorage("editorDarkTheme") var editorDarkTheme: String = "Default"
    @AppStorage("editorFontSize") var editorTextSize: Int = 14

    @State var targeted: Bool = false

    func onDropURL(url: URL) {
        // TODO: Determine whether file is directory
        _ = url.startAccessingSecurityScopedResource()
        App.openFile(url: url, alwaysInNewTab: true)
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                // Invisible buttons for creating keyboard shortcuts in SwiftUI
                VStack {
                    Button("New File") {
                        stateManager.showsNewFileSheet.toggle()
                    }.keyboardShortcut("n", modifiers: [.command])

                    Button("Open File") {
                        stateManager.showsFilePicker.toggle()
                    }
                    .keyboardShortcut("o", modifiers: [.command])
                    .sheet(isPresented: $stateManager.showsFilePicker) {
                        DocumentPickerView()
                    }

                    Button("Save") {
                        App.saveCurrentFile()

                    }
                    .keyboardShortcut("s", modifiers: [.command])
                    .sheet(
                        isPresented: $stateManager.showsChangeLog,
                        content: {
                            ChangeLogView()
                        })

                    Button("Close Editor") {
                        if let activeEditor = App.activeEditor {
                            App.closeEditor(editor: activeEditor)
                        }
                    }
                    .keyboardShortcut("w", modifiers: [.command])
                    .sheet(isPresented: $stateManager.showsDirectoryPicker) {
                        DirectoryPickerView(onOpen: { url in
                            App.loadFolder(url: url)
                        })
                    }
                }.foregroundColor(.clear).font(.system(size: 1))

                Color.init(id: "editor.background")

                if !App.stateManager.isMonacoEditorInitialized {
                    App.monacoInstance
                        .overlay {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.init(id: "editor.background"))
                        }
                } else if let editor = App.activeEditor {
                    ZStack {

                        VStack {
                            Button("Command Palatte") {
                                App.monacoInstance.executeJavascript(
                                    command: "editor.trigger('', 'editor.action.quickCommand')")
                            }
                            .keyboardShortcut("p", modifiers: [.command, .shift])

                            Button("Zoom in") {
                                if self.editorTextSize < 30 {
                                    self.editorTextSize += 1
                                    App.monacoInstance.executeJavascript(
                                        command:
                                            "editor.updateOptions({fontSize: \(String(self.editorTextSize))})"
                                    )
                                }
                            }.keyboardShortcut("+", modifiers: [.command])

                            Button("Zoom out") {
                                if self.editorTextSize > 10 {
                                    self.editorTextSize -= 1
                                    App.monacoInstance.executeJavascript(
                                        command:
                                            "editor.updateOptions({fontSize: \(String(self.editorTextSize))})"
                                    )
                                }
                            }.keyboardShortcut("-", modifiers: [.command])
                        }.foregroundColor(.clear).font(.system(size: 1))

                        editor.view
                    }
                } else {
                    DescriptionText("You don't have any open editor.")
                }

                VStack {
                    InfinityProgressView(enabled: App.workSpaceStorage.editorIsBusy)
                    Spacer()
                }

            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("editor.focus"),
                    object: nil),
                perform: { notification in
                    guard let sceneIdentifier = notification.userInfo?["sceneIdentifier"] as? UUID,
                        sceneIdentifier != App.sceneIdentifier
                    else { return }
                    Task {
                        try await App.monacoInstance.blur()
                    }
                }
            )
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("terminal.focus"),
                    object: nil),
                perform: { notification in
                    Task {
                        try await App.monacoInstance.blur()
                    }
                }
            )
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification),
                perform: { data in
                    guard
                        !App.alertManager.isShowingAlert,
                        let beginRect = data.userInfo?["UIKeyboardFrameBeginUserInfoKey"]
                            as? CGRect,
                        let endRect = data.userInfo?["UIKeyboardFrameEndUserInfoKey"] as? CGRect,
                        beginRect.origin.y != endRect.origin.y
                    else {
                        return
                    }

                    Task {
                        if await App.monacoInstance.isEditorInFocus() {
                            await App.saveCurrentFile()
                            try await App.monacoInstance.blur()
                        }
                    }
                }
            )

        }.onDrop(
            of: [.url, .item], isTargeted: $targeted,
            perform: { providers in
                if let provider = providers.first {
                    if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        _ = provider.loadObject(
                            ofClass: URL.self,
                            completionHandler: { url, err in
                                if let url {
                                    onDropURL(url: url)
                                }
                            })
                    } else {
                        provider.loadItem(forTypeIdentifier: UTType.item.identifier) {
                            data, error in
                            if let url = data as? URL {
                                onDropURL(url: url)
                            }
                        }
                    }

                }
                return true
            })

    }
}
