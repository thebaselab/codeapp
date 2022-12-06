//
//  ThemeManager.swift
//  Code
//
//  Created by Ken Chung on 6/12/2022.
//

import SwiftUI

// TODO: Move these into ThemeManager
var globalDarkTheme: [String: Any]? = nil
var globalLightTheme: [String: Any]? = nil

class ThemeManager: ObservableObject {

    @AppStorage("editorLightTheme") var selectedLightTheme: String = "Light+"
    @AppStorage("editorDarkTheme") var selectedTheme: String = "Dark+"

    var themes: [Theme] = []
    @Published var currentTheme: Theme? = nil

    init() {
        loadBuiltInThemes()
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
                    globalDarkTheme = jsonArray
                    currentTheme = theme
                }
                if selectedLightTheme == name && type != "dark" {
                    globalLightTheme = jsonArray
                    currentTheme = theme
                }
            } else {
                print("READ ERROR: \(path)")
            }
        }
    }
}
