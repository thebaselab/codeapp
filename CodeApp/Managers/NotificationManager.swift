//
//  NotificationManager.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

class NotificationManager: ObservableObject {
    @Published var notifications: [NotificationEntry] = []
    @Published var isShowingAllBanners = false

    func postProgressNotification(title: String, progress: Progress) {
        let title = NSLocalizedString(title, comment: "")
        notifications.append(
            NotificationEntry.init(
                data: NotificationData.init(
                    title: title, progress: progress, level: .info, style: .progress)))
    }

    func postActionNotification(
        title: String, level: NotificationData.Level, primary: @escaping (() -> Void),
        primaryTitle: String, source: String
    ) {
        let title = NSLocalizedString(title, comment: "")
        let primaryTitle = NSLocalizedString(primaryTitle, comment: "")
        let source = NSLocalizedString(source, comment: "")
        notifications.append(
            NotificationEntry.init(
                data: NotificationData.init(
                    title: title, source: source, level: level, style: .action,
                    primaryAction: primary, primaryTitle: primaryTitle)))
    }

    func showAsyncNotification(
        title: String, task: @escaping (() async -> Void)
    ) {
        let title = NSLocalizedString(title, comment: "")
        var data = NotificationData.init(
            title: title, level: .info, style: .infinityProgress)
        data.task = task

        DispatchQueue.main.async {
            self.notifications.append(
                NotificationEntry(data: data)
            )
        }
    }

    func showInformationMessage(_ mes: String) {
        let mes = NSLocalizedString(mes, comment: "")
        DispatchQueue.main.async {
            self.notifications.append(
                NotificationEntry.init(
                    data: NotificationData.init(title: mes, level: .info, style: .basic)))
        }
    }

    func showWarningMessage(_ mes: String) {
        let mes = NSLocalizedString(mes, comment: "")
        DispatchQueue.main.async {
            self.notifications.append(
                NotificationEntry.init(
                    data: NotificationData.init(title: mes, level: .warning, style: .basic))
            )
        }
    }

    func showErrorMessage(_ mes: String) {
        let mes = NSLocalizedString(mes, comment: "")
        DispatchQueue.main.async {
            self.notifications.append(
                NotificationEntry.init(
                    data: NotificationData.init(title: mes, level: .error, style: .basic)))
        }
    }

}
