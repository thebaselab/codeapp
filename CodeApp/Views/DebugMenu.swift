//
//  DebugMenu.swift
//  Code
//
//  Created by Ken Chung on 18/11/2022.
//

import SwiftUI

struct DebugMenu: View {

    @EnvironmentObject var App: MainApp

    var body: some View {
        Section("UI Debug Menu") {
            Button("Regular Notification") {
                App.notificationManager.showErrorMessage("Error")
            }
            Button("Progress Notification") {
                App.notificationManager.postProgressNotification(
                    title: "Progress", progress: Progress())
            }
            Button("Action Notification") {
                App.notificationManager.postActionNotification(
                    title: "Error", level: .error, primary: {},
                    primaryTitle: "primaryTitle", source: "source")
            }
            Button("Async Notification") {
                App.notificationManager.showAsyncNotification(
                    title: "Task Name",
                    task: {
                        try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                    })
            }
        }
    }
}
