//
//  theme.swift
//  Code
//
//  Created by Ken Chung on 19/3/2021.
//

import SwiftUI

struct themeConfigView: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var AppStore: Store

    static let lightPlusTheme = theme(
        name: "Light+", url: URL(string: "https://thebaselab.com")!, isDark: false,
        preview: (
            .init(hexString: "#FFFFFF"), .init(hexString: "#2C2C2C"), .init(hexString: "#0D7ACC"),
            .init(hexString: "#F3F3F3")
        ))
    static let darkPlusTheme = theme(
        name: "Dark+", url: URL(string: "https://thebaselab.com")!, isDark: true,
        preview: (
            .init(hexString: "#1E1E1E"), .init(hexString: "#333333"), .init(hexString: "#0D7ACC"),
            .init(hexString: "#252526")
        ))

    var themeSection: some View {
        VStack(alignment: .leading) {
            Text("Dark Themes")
                .font(.system(size: 20, weight: .bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {

                    ForEach(
                        [themeConfigView.darkPlusTheme] + globalThemes.filter { $0.isDark },
                        id: \.id
                    ) { item in
                        themePreview(item: item)
                            .environmentObject(App)
                    }

                }
                .frame(height: 150)
            }

            Text("Light Themes")
                .font(.system(size: 20, weight: .bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(
                        [themeConfigView.lightPlusTheme] + globalThemes.filter { !$0.isDark },
                        id: \.id
                    ) { item in
                        themePreview(item: item)
                            .environmentObject(App)
                    }
                }
                .frame(height: 150)
            }
            Spacer()
        }
    }

    var subscriptionSection: some View {
        Group {
            if let product = AppStore.subscriptions.first {
                VStack(alignment: .leading) {
                    Spacer()

                    Group {
                        Text("subscription.codeplus")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("subscription.title \(product.displayPrice)")
                            .font(.largeTitle)
                            .fontWeight(.semibold)

                        Text("subscription.message")
                            .lineLimit(5)

                        Divider()

                        Text(
                            "subscription.payment.description \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)) \(product.displayPrice)"
                        )

                    }.foregroundColor(.white)

                    HStack(alignment: .center) {
                        if AppStore.canMakePayments {
                            Button(action: {
                                Task {
                                    _ = try? await AppStore.purchase(product)
                                }
                            }) {
                                Text("subscription.join")
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                    .padding(10)
                                    .background(.white)
                                    .cornerRadius(6)
                            }
                        } else {
                            Text("subscription.payment.disallowed")
                        }
                    }

                    HStack {
                        Spacer()
                        Link(destination: URL(string: "https://thebaselab.com/privacypolicies/")!) {
                            Label("code.and.privacy", systemImage: "lock")
                        }
                        .foregroundColor(.white)
                        .font(.body.bold())
                    }

                    Spacer()
                }.frame(maxWidth: 500)
            }
        }

    }

    var body: some View {
        ZStack {
            themeSection
                .if(!AppStore.isSubscribed && !AppStore.isPurchasedBeforeFree) { view in
                    view
                        .disabled(true)
                        .blur(radius: 4)
                }
                .padding()

            if !AppStore.isSubscribed && !AppStore.isPurchasedBeforeFree {
                VStack {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.green]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .frame(maxHeight: 400)
                .edgesIgnoringSafeArea(.horizontal)
                .overlay(subscriptionSection.padding())
                .cornerRadius(10)
            }
        }
    }
}
