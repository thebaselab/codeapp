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

    @AppStorage("editorLightTheme") var editorLightTheme: String = "Default"
    @AppStorage("editorDarkTheme") var editorDarkTheme: String = "Default"

    @State var targeted: Bool = false

    func onDropURL(url: URL) {
        // TODO: Determine whether file is directory
        _ = url.startAccessingSecurityScopedResource()
        App.openFile(url: url, alwaysInNewTab: true)
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Color.init(id: "editor.background")
                if !App.monacoInstance.monacoWebView.isEditorInited {
                    App.monacoInstance
                } else if let editor = App.activeEditor {

                    editor.view

                    VStack {
                        InfinityProgressView(enabled: App.workSpaceStorage.editorIsBusy)
                        Spacer()
                    }

                } else {
                    DescriptionText("You don't have any open editor.")
                }

            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("monaco.cursor.position.changed"),
                    object: nil),
                perform: { notification in
                    let sceneIdentifier = notification.userInfo?["sceneIdentifier"] as! UUID
                    if sceneIdentifier != App.sceneIdentifier {
                        App.monacoInstance.executeJavascript(
                            command: "document.getElementById('overlay').focus()")
                    }
                }
            )
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification),
                perform: { data in
                    if let beginRect = data.userInfo?["UIKeyboardFrameBeginUserInfoKey"] as? CGRect,
                        let endRect = data.userInfo?["UIKeyboardFrameEndUserInfoKey"] as? CGRect
                    {

                        App.saveCurrentFile()

                        App.monacoInstance.monacoWebView.evaluateJavaScript(
                            "document.activeElement.className"
                        ) {
                            result, error in
                            if let res = result as? String {
                                if res != "shadow-root-host" && res != "actions-container"
                                    && !res.contains("monaco-list")
                                {
                                    if beginRect.origin.y != endRect.origin.y {
                                        App.monacoInstance.executeJavascript(
                                            command: "document.getElementById('overlay').focus()")
                                    }
                                }
                            }
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
