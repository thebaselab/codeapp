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

    func postProgressNotification(title: String, progress: Progress, _ arguments: CVarArg...) {
        let title = String(format: NSLocalizedString(title, comment: ""), arguments)
        DispatchQueue.main.async {
            self.notifications.append(
                NotificationEntry.init(
                    data: NotificationData.init(
                        title: title, progress: progress, level: .info, style: .progress)))
        }
    }
    func postActionNotification(
        title: String, level: NotificationData.Level, primary: @escaping (() -> Void),
        primaryTitle: String, source: String, _ arguments: CVarArg...
    ) {
        let title = String(format: NSLocalizedString(title, comment: ""), arguments)
        let primaryTitle = String(format: NSLocalizedString(primaryTitle, comment: ""), arguments)
        let source = String(format: NSLocalizedString(source, comment: ""), arguments)
        DispatchQueue.main.async {
            self.notifications.append(
                NotificationEntry.init(
                    data: NotificationData.init(
                        title: title, source: source, level: level, style: .action,
                        primaryAction: primary, primaryTitle: primaryTitle)))
        }
    }

    func postActionNotification(
        title: String, level: NotificationData.Level, primary: @escaping (() -> Void),
        primaryTitle: String, secondary: @escaping (() -> Void), secondaryTitle: String,
        source: String, _ arguments: CVarArg...
    ) {
        let title = String(format: NSLocalizedString(title, comment: ""), arguments)
        let primaryTitle = String(format: NSLocalizedString(primaryTitle, comment: ""), arguments)
        let secondaryTitle = String(
            format: NSLocalizedString(secondaryTitle, comment: ""), arguments)
        let source = String(format: NSLocalizedString(source, comment: ""), arguments)
        DispatchQueue.main.async {
            self.notifications.append(
                NotificationEntry.init(
                    data: NotificationData.init(
                        title: title, source: source, level: level, style: .action,
                        primaryAction: primary, secondaryAction: secondary,
                        primaryTitle: primaryTitle, secondaryTitle: secondaryTitle)))
        }
    }

    func withAsyncNotification(
        title: String, task: @escaping (() async throws -> Void), _ arguments: CVarArg...
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            showAsyncNotification(
                title: title,
                task: {
                    do {
                        try await task()
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                },
                arguments
            )
        }
    }

    func showAsyncNotification(
        title: String, task: @escaping (() async -> Void), _ arguments: CVarArg...
    ) {
        let title = String(format: NSLocalizedString(title, comment: ""), arguments)
        var data = NotificationData.init(
            title: title, level: .info, style: .infinityProgress)
        data.task = task

        DispatchQueue.main.async {
            self.notifications.append(
                NotificationEntry(data: data)
            )
        }
    }

    func showInformationMessage(_ mes: String, _ arguments: CVarArg...) {
        let mes = String(format: NSLocalizedString(mes, comment: ""), arguments)
        DispatchQueue.main.async {
            self.notifications.append(
                NotificationEntry.init(
                    data: NotificationData.init(title: mes, level: .info, style: .basic)))
        }
    }

    func showWarningMessage(_ mes: String, _ arguments: CVarArg...) {
        let mes = String(format: NSLocalizedString(mes, comment: ""), arguments)
        DispatchQueue.main.async {
            self.notifications.append(
                NotificationEntry.init(
                    data: NotificationData.init(title: mes, level: .warning, style: .basic))
            )
        }
    }

    func showErrorMessage(_ mes: String, _ arguments: CVarArg...) {
        let mes = String(format: NSLocalizedString(mes, comment: ""), arguments)
        DispatchQueue.main.async {
            self.notifications.append(
                NotificationEntry.init(
                    data: NotificationData.init(title: mes, level: .error, style: .basic)))
        }
    }

}
