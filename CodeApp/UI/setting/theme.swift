//
//  theme.swift
//  Code
//
//  Created by Ken Chung on 19/3/2021.
//

import SwiftUI

struct themeConfigView: View {

    @EnvironmentObject var App: MainApp

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

    var body: some View {
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
        .padding()
    }
}
