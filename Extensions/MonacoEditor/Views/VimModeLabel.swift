//
//  VimModeLabel.swift
//  Code
//
//  Created by Ken Chung on 12/01/2024.
//

import SwiftUI

struct VimModeLabel: View {
    @EnvironmentObject var App: MainApp
    @State var mode = "--NORMAL--"
    @AppStorage("editorOptions") var editorOptions: CodableWrapper<EditorOptions> = .init(
        value: EditorOptions())

    var body: some View {
        Text(editorOptions.value.vimEnabled ? mode : "")
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("vim.mode.change"),
                    object: nil),
                perform: { notification in
                    guard
                        let sceneIdentifier =
                            notification.userInfo?["sceneIdentifier"] as? UUID,
                        sceneIdentifier == App.sceneIdentifier
                    else { return }

                    if let newMode = notification.userInfo?["newMode"] as? String {
                        mode = newMode
                    }
                }
            )
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("vim.clear"),
                    object: nil),
                perform: { notification in
                    guard
                        let sceneIdentifier =
                            notification.userInfo?["sceneIdentifier"] as? UUID,
                        sceneIdentifier == App.sceneIdentifier
                    else { return }

                    mode = ""
                })
    }
}
