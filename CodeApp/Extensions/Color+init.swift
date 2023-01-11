//
//  Color+init.swift
//  Code
//
//  Created by Ken Chung on 18/3/2021.
//

import SwiftUI

extension UIColor {
    convenience init(id: String) {
        self.init(Color(id: id))
    }

    // Defining dynamic colors in Swift
    // https://www.swiftbysundell.com/articles/defining-dynamic-colors-in-swift/
    convenience init(
        light lightModeColor: @escaping @autoclosure () -> UIColor,
        dark darkModeColor: @escaping @autoclosure () -> UIColor
    ) {
        self.init { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .light:
                return lightModeColor()
            case .dark:
                return darkModeColor()
            case .unspecified:
                return lightModeColor()
            @unknown default:
                return lightModeColor()
            }
        }
    }
}

extension Color {
    init(id: String) {

        var lightColor = UIColor(named: id) ?? .gray
        var darkColor = UIColor(named: id) ?? .gray

        if let globalDarkTheme {
            let darkColorDict = globalDarkTheme["colors"] as! [String: String]
            if let hexString = darkColorDict[id] {
                darkColor = UIColor(Color(hexString: hexString))
            }
        }

        if let globalLightTheme {
            let lightColorDict = globalLightTheme["colors"] as! [String: String]
            if let hexString = lightColorDict[id] {
                lightColor = UIColor(Color(hexString: hexString))
            }
        }

        self.init(
            UIColor(
                light: lightColor,
                dark: darkColor
            )
        )
    }

    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        //        case 4: // RGBA (12-bit)
        //            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // RGBA (32-bit)
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
