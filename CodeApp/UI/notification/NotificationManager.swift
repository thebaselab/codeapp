//
//  notification.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

class NotificationManager: ObservableObject {
    @Published var banners: [BannerModule] = []
    @Published var isShowingAllBanners = false

    func postProgressNotification(title: String, progress: Progress) {
        let title = NSLocalizedString(title, comment: "")
        banners.append(
            BannerModule.init(
                data: BannerData.init(
                    title: title, progress: progress, level: .info, style: .progress)))
    }

    func postActionNotification(
        title: String, level: BannerData.Level, primary: @escaping (() -> Void),
        primaryTitle: String, source: String
    ) {
        let title = NSLocalizedString(title, comment: "")
        let primaryTitle = NSLocalizedString(primaryTitle, comment: "")
        let source = NSLocalizedString(source, comment: "")
        banners.append(
            BannerModule.init(
                data: BannerData.init(
                    title: title, source: source, level: level, style: .action,
                    primaryAction: primary, primaryTitle: primaryTitle)))
    }

    func showInformationMessage(_ mes: String) {
        let mes = NSLocalizedString(mes, comment: "")
        DispatchQueue.main.async {
            self.banners.append(
                BannerModule.init(data: BannerData.init(title: mes, level: .info, style: .basic)))
        }
    }

    func showWarningMessage(_ mes: String) {
        let mes = NSLocalizedString(mes, comment: "")
        DispatchQueue.main.async {
            self.banners.append(
                BannerModule.init(data: BannerData.init(title: mes, level: .warning, style: .basic))
            )
        }
    }

    func showErrorMessage(_ mes: String) {
        let mes = NSLocalizedString(mes, comment: "")
        DispatchQueue.main.async {
            self.banners.append(
                BannerModule.init(data: BannerData.init(title: mes, level: .error, style: .basic)))
        }
    }

}

struct BannerModule: Identifiable {
    let id = UUID()
    let data: BannerData
    var isPresented: Bool = true
    var isRemoved: Bool = false
}

struct BannerData {
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

        var icon: some View {
            switch self {
            case .error:
                return Image(systemName: "xmark.circle.fill").font(.subheadline)
                    .foregroundColor(Color.red)
            case .info:
                return Image(systemName: "info.circle.fill").font(.subheadline)
                    .foregroundColor(Color.blue)
            case .warning:
                return Image(systemName: "exclamationmark.triangle.fill").font(.subheadline)
                    .foregroundColor(Color.yellow)
            case .success:
                return Image(systemName: "checkmark.circle.fill").font(.subheadline)
                    .foregroundColor(Color.green)
            }
        }
    }
}

extension BannerData {
    func makeBanner(isPresented: Binding<Bool>, isRemoved: Binding<Bool>) -> some View {
        switch style {
        case .progress:
            return AnyView(
                BannerWtihProgress(data: self, isPresented: isPresented, isRemoved: isRemoved))
        case .basic:
            return AnyView(Banner(data: self, isPresented: isPresented, isRemoved: isRemoved))
        case .action:
            return AnyView(
                BannerWithButton(data: self, isPresented: isPresented, isRemoved: isRemoved))
        }
    }
}
