//
//  SettingsThemeConfiguration.swift
//  Code
//
//  Created by Ken Chung on 19/3/2021.
//

import SwiftUI

struct SettingsThemeConfiguration: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var themeManager: ThemeManager

    var themeSection: some View {
        List {
            Section("Dark Themes") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {

                        ForEach(
                            themeManager.themes
                                .filter { $0.name == "Dark+" }
                                + themeManager.themes
                                .filter { $0.isDark }
                                .filter { $0.name != "Dark+" }
                                .sorted { $0.name < $1.name },
                            id: \.id
                        ) { item in
                            ThemePreview(item: item)
                                .environmentObject(App)
                        }

                    }
                    .frame(height: 150)
                }
            }.listRowBackground(Color.clear)

            Section("Light Themes") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(
                            themeManager.themes
                                .filter { $0.name == "Light+" }
                                + themeManager.themes
                                .filter { !$0.isDark }
                                .filter { $0.name != "Light+" }
                                .sorted { $0.name < $1.name },
                            id: \.id
                        ) { item in
                            ThemePreview(item: item)
                                .environmentObject(App)
                        }
                    }
                    .frame(height: 150)
                }
            }.listRowBackground(Color.clear)
        }
        .navigationTitle("Themes")
    }

    var body: some View {
        themeSection.background(Color(id: "sideBar.background"))
    }
}

struct ThemePreview: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var themeManager: ThemeManager

    var item: Theme

    @AppStorage("editorLightTheme") var selectedLightTheme: String = "Light+"
    @AppStorage("editorDarkTheme") var selectedTheme: String = "Dark+"

    var body: some View {
        VStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(item.preview.1)
                        .aspectRatio(1 / 11, contentMode: .fit)

                    Rectangle()
                        .fill(item.preview.3)
                        .aspectRatio(4 / 11, contentMode: .fit)

                    Rectangle()
                        .fill(item.preview.0)
                }
                Rectangle()
                    .fill(item.preview.2)
                    .aspectRatio(16 / 1, contentMode: .fit)
            }
            .if(
                (item.isDark && (item.name == selectedTheme))
                    || (!item.isDark && (item.name == selectedLightTheme))
            ) {
                $0.overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue, lineWidth: 6)
                )
            }
            .aspectRatio(4 / 3, contentMode: .fit)
            .cornerRadius(10)

            Text(item.name)
                .font(.system(size: 16, weight: .regular))
        }.onTapGesture {
            themeManager.setTheme(theme: item)
        }
    }
}
