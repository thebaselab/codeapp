//
//  NotificationCentreView.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

struct NotificationCentreView: View {

    @EnvironmentObject var App: MainApp

    var body: some View {
        VStack(spacing: 10) {
            ForEach(App.notificationManager.notifications.indices, id: \.self) { i in
                if !App.notificationManager.notifications[i].isRemoved
                    && (App.notificationManager.notifications[i].isPresented
                        || App.notificationManager.isShowingAllBanners)
                {
                    withAnimation(.spring()) {
                        App.notificationManager.notifications[i].data.makeView(
                            isPresented: $App.notificationManager.notifications[i].isPresented,
                            isRemoved: $App.notificationManager.notifications[i].isRemoved)
                    }
                }
            }
        }
    }
}

private struct NotificationItem<V: View>: View {
    let children: () -> V

    init(@ViewBuilder children: @escaping () -> V) {
        self.children = children
    }

    var body: some View {
        VStack {
            children()
                .frame(minHeight: 50)
                .padding(.horizontal, 10)
        }
        .frame(maxWidth: 300)
        .background(Color.init(id: "sideBar.background"))
        .cornerRadius(10)
    }
}

private struct SimpleNotificationItem: View {

    let data: NotificationData
    @Binding var isPresented: Bool
    @Binding var isRemoved: Bool

    var body: some View {
        NotificationItem {
            HStack {
                data.level.icon
                Text(data.title).lineLimit(5).font(.subheadline).foregroundColor(
                    Color.init("T1"))
                Spacer()
            }
        }
        .onTapGesture {
            withAnimation {
                isRemoved = true
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                withAnimation {
                    isPresented = false
                }
            }
        }
    }
}

private struct NotificationItemWtihProgress: View {

    let data: NotificationData
    @Binding var isPresented: Bool
    @Binding var isRemoved: Bool

    var body: some View {
        NotificationItem {
            VStack {
                HStack {
                    data.level.icon
                    Text(data.title).lineLimit(1).font(.subheadline).foregroundColor(
                        Color.init("T1"))
                    Spacer()
                }.frame(height: 50).padding(.leading, 10).padding(.trailing, 10)

                ProgressView(data.progress!).padding(
                    EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10)
                ).onChange(
                    of: data.progress,
                    perform: { value in
                        if data.progress!.isFinished {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation {
                                    isRemoved = true
                                }
                            }
                        }
                    }
                )
                .progressViewStyle(LinearProgressViewStyle())
            }
        }
        .onTapGesture {
            withAnimation {
                isRemoved = true
            }
        }
    }
}

private struct NotificationItemWithButton: View {

    let data: NotificationData
    @Binding var isPresented: Bool
    @Binding var isRemoved: Bool

    var body: some View {
        VStack {
            HStack {
                data.level.icon
                Text(data.title).lineLimit(2).font(.subheadline).foregroundColor(
                    Color.init("T1"))
                Spacer()
                Image(systemName: "xmark").font(.system(size: 12)).foregroundColor(Color.init("T1"))
                    .onTapGesture { isRemoved = true }
            }.frame(height: 50).padding(.leading, 10).padding(.trailing, 10)

            HStack {
                Text("Source: \(data.source ?? "")").lineLimit(2).font(.system(size: 12))
                    .foregroundColor(Color.gray)
                Spacer()
                if data.primaryAction != nil {
                    Text(data.primaryTitle).foregroundColor(.white).lineLimit(1).font(
                        .system(size: 12)
                    ).padding(.leading, 8).padding(.trailing, 8).padding(.top, 4).padding(
                        .bottom, 4
                    ).background(Color.init(id: "statusBar.background")).cornerRadius(10)
                        .onTapGesture {
                            data.primaryAction?()
                            withAnimation {
                                isRemoved = true
                            }
                        }
                }
                if data.secondaryAction != nil {
                    Text(data.secondaryTitle).foregroundColor(.white).lineLimit(1).font(
                        .system(size: 12)
                    ).padding(.leading, 8).padding(.trailing, 8).padding(.top, 4).padding(
                        .bottom, 4
                    ).background(Color.init(id: "statusBar.background")).cornerRadius(10)
                        .onTapGesture {
                            data.secondaryAction?()
                            withAnimation {
                                isRemoved = true
                            }
                        }
                }

            }.frame(height: 30).padding(.leading, 10).padding(.trailing, 10).padding(.bottom, 10)

        }.frame(maxWidth: 300).background(Color.init(id: "sideBar.background")).cornerRadius(10)
    }
}

extension NotificationData.Level {
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

extension NotificationData {
    func makeView(isPresented: Binding<Bool>, isRemoved: Binding<Bool>) -> some View {
        switch style {
        case .progress:
            return AnyView(
                NotificationItemWtihProgress(
                    data: self, isPresented: isPresented, isRemoved: isRemoved))
        case .basic:
            return AnyView(
                SimpleNotificationItem(data: self, isPresented: isPresented, isRemoved: isRemoved))
        case .action:
            return AnyView(
                NotificationItemWithButton(
                    data: self, isPresented: isPresented, isRemoved: isRemoved))
        }
    }
}
