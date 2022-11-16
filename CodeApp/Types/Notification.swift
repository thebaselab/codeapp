//
//  Notification.swift
//  Code
//
//  Created by Ken Chung on 13/11/2022.
//

import Foundation
import SwiftUI

struct NotificationEntry: Identifiable {
    let id = UUID()
    let data: NotificationData
    var isPresented: Bool = true
    var isRemoved: Bool = false
}

struct NotificationData {
    let title: String
    var source: String? = nil
    var progress: Progress? = nil
    let level: Level
    let style: Style
    var primaryAction: (() -> Void)? = nil
    var secondaryAction: (() -> Void)? = nil
    var primaryTitle: String = ""
    var secondaryTitle: String = ""

    enum Style {
        case basic
        case action
        case progress
    }

    enum Level {
        case warning
        case info
        case error
        case success
    }
}
