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
    @AppStorage("editor.vim.enabled") var editorVimEnabled: Bool = false

    var body: some View {
        Text(editorVimEnabled ? mode : "")
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
