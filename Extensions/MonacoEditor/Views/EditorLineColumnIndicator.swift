//
//  EditorLineColumnIndicator.swift
//  Code
//
//  Created by Ken Chung on 15/8/2023.
//

import SwiftUI

struct EditorLineColumnIndicator: View {
    @EnvironmentObject var App: MainApp

    @State var currentLine = 0
    @State var currentColumn = 0

    var body: some View {
        Text("Ln \(String(currentLine)), Col \(String(currentColumn))")
            .onTapGesture {
                App.monacoInstance.executeJavascript(
                    command:
                        "editor.focus();editor.trigger('', 'editor.action.gotoLine')"
                )
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("monaco.cursor.position.changed"),
                    object: nil),
                perform: { notification in
                    guard
                        let sceneIdentifier =
                            notification.userInfo?["sceneIdentifier"] as? UUID,
                        sceneIdentifier == App.sceneIdentifier
                    else { return }

                    currentLine = notification.userInfo?["lineNumber"] as! Int
                    currentColumn = notification.userInfo?["column"] as! Int
                })
    }
}
