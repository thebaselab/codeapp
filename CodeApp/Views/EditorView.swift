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
                if !App.stateManager.isMonacoEditorInitialized {
                    App.monacoInstance
                        .overlay {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.init(id: "editor.background"))
                        }
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
