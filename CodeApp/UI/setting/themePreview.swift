//
//  themePreview.swift
//  Code
//
//  Created by Ken Chung on 21/3/2021.
//

import SwiftUI

struct themePreview: View {

    @EnvironmentObject var App: MainApp

    @State var item: Theme

    @AppStorage("editorLightTheme") var selectedLightTheme: String = "Light+"
    @AppStorage("editorDarkTheme") var selectedTheme: String = "Dark+"

    func setTheme() {
        App.updateView()

        if item.url.scheme == "https" {
            if item.isDark {
                globalDarkTheme = nil
                selectedTheme = item.name
                App.monacoInstance.executeJavascript(command: "resetTheme(true)")
                App.terminalInstance.executeScript("applyTheme(null, true)")
            } else {
                globalLightTheme = nil
                selectedLightTheme = item.name
                App.monacoInstance.executeJavascript(command: "resetTheme(false)")
                App.terminalInstance.executeScript("applyTheme(null, false)")
            }
            return
        }

        let data = try! Data(contentsOf: item.url)
        let jsonArray =
            try! JSONSerialization.jsonObject(with: data, options: .allowFragments)
            as! [String: Any]

        if item.isDark {
            globalDarkTheme = jsonArray
            selectedTheme = item.name
        } else {
            globalLightTheme = jsonArray
            selectedLightTheme = item.name
        }

        let content = String(data: data, encoding: .utf8)!

        App.monacoInstance.setTheme(
            themeName: item.name.replacingOccurrences(of: " ", with: ""), data: content,
            isDark: item.isDark)
        App.terminalInstance.applyTheme(rawTheme: jsonArray)

    }

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
            setTheme()
        }
    }
}

//struct themePreview_Previews: PreviewProvider {
//    static var previews: some View {
//        themePreview(item: theme(name: "Dark+", url: URL(string: "https://thebaselab.com")!, isDark: true, preview: (.init(hexString: "#1E1E1E"), .init(hexString: "#333333"), .init(hexString: "#0D7ACC"), .init(hexString: "#252526"))))
//    }
//}
