//
//  ThemeManager.swift
//  Code
//
//  Created by Ken Chung on 6/12/2022.
//

import SwiftUI

class ThemeManager: ObservableObject {

    @AppStorage("editorLightTheme") var selectedLightTheme: String = "Light+"
    @AppStorage("editorDarkTheme") var selectedTheme: String = "Dark+"
    @AppStorage("preferredColorScheme") var preferredColorScheme: Int = 0

    var colorSchemePreference: ColorScheme? {
        preferredColorScheme == 1 ? .dark : preferredColorScheme == 2 ? .light : nil
    }

    var themes: [Theme] = []
    @Published var currentTheme: Theme? = nil

    static var lightTheme: Theme? = nil
    static var darkTheme: Theme? = nil

    init() {
        loadBuiltInThemes()
    }

    func setTheme(theme: Theme) {
        if theme.isDark {
            ThemeManager.darkTheme = theme
            selectedTheme = theme.name
        } else {
            ThemeManager.lightTheme = theme
            selectedLightTheme = theme.name
        }
        currentTheme = theme

        let notification = Notification(
            name: Notification.Name("theme.updated")
        )
        NotificationCenter.default.post(notification)
    }

    private func loadBuiltInThemes() {
        themes.removeAll()

        let themesPaths = try! FileManager.default.contentsOfDirectory(
            at: Resources.themes, includingPropertiesForKeys: nil)

        for path in themesPaths {
            if let data = try? Data(contentsOf: path),
                let jsonArray = try? JSONSerialization.jsonObject(
                    with: data, options: .allowFragments) as? [String: Any],
                let name = jsonArray["name"] as? String,
                let type = jsonArray["type"] as? String,
                let colorArray = jsonArray["colors"] as? [String: String]
            {
                let previewColors = [
                    "editor.background", "activityBar.background", "statusBar.background",
                    "sideBar.background",
                ]
                let preview = previewColors.map { Color.init(hexString: colorArray[$0] ?? $0) }
                let result = (preview[0], preview[1], preview[2], preview[3])
                let theme = Theme(name: name, url: path, isDark: type == "dark", preview: result)

                themes.append(theme)

                if selectedTheme == name && type == "dark" {
                    ThemeManager.darkTheme = theme
                    currentTheme = theme
                }
                if selectedLightTheme == name && type != "dark" {
                    ThemeManager.lightTheme = theme
                    currentTheme = theme
                }
            } else {
                print("READ ERROR: \(path)")
            }
        }
    }
}
