//
//  VimKeyBufferLabel.swift
//  Code
//
//  Created by Ken Chung on 12/01/2024.
//

import SwiftUI

struct VimKeyBufferLabel: View {
    @EnvironmentObject var App: MainApp
    @State var keyBuffer = ""

    var body: some View {
        Text(keyBuffer)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("vim.keybuffer.set"),
                    object: nil),
                perform: { notification in
                    guard
                        let sceneIdentifier =
                            notification.userInfo?["sceneIdentifier"] as? UUID,
                        sceneIdentifier == App.sceneIdentifier
                    else { return }

                    if let newKeyBuffer = notification.userInfo?["buffer"] as? String {
                        keyBuffer = newKeyBuffer
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

                    keyBuffer = ""
                })
    }
}
