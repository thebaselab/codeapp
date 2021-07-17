//
//  Color+init.swift
//  Code
//
//  Created by Ken Chung on 18/3/2021.
//

import SwiftUI

extension Color {
    init(id: String){
        
        let jsonArray: Dictionary<String, Any>
        
        if UserDefaults.standard.integer(forKey: "preferredColorScheme") == 1 {
            if globalDarkTheme != nil {
                jsonArray = globalDarkTheme!
            }else{
                let color = UIColor(named: id)?.resolvedColor(with: UITraitCollection( userInterfaceStyle: .dark)) ?? UIColor.gray
                self.init(color)
                return
            }
        }else if UserDefaults.standard.integer(forKey: "preferredColorScheme") == 2 {
            if globalLightTheme != nil {
                jsonArray = globalLightTheme!
            }else{
                let color = UIColor(named: id)?.resolvedColor(with: UITraitCollection( userInterfaceStyle: .light)) ?? UIColor.gray
                self.init(color)
                return
            }
        }else{
            if UITraitCollection.current.userInterfaceStyle == .dark && globalDarkTheme != nil {
                jsonArray = globalDarkTheme!
            }else if UITraitCollection.current.userInterfaceStyle != .dark && globalLightTheme != nil{
                jsonArray = globalLightTheme!
            }else {
                if UITraitCollection.current.userInterfaceStyle == .dark {
                    let color = UIColor(named: id)?.resolvedColor(with: UITraitCollection( userInterfaceStyle: .dark)) ?? UIColor.gray
                    self.init(color)
                }else{
                    let color = UIColor(named: id)?.resolvedColor(with: UITraitCollection( userInterfaceStyle: .light)) ?? UIColor.gray
                    self.init(color)
                }
                return
            }
        }
        
        let colorArray = jsonArray["colors"] as! Dictionary<String, String>
        
        for key in colorArray.keys {
            if key == id {
                self.init(hexString: colorArray[key]!)
                return
            }
        }
        
        self.init(id)
    }
    
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
//        case 4: // RGBA (12-bit)
//            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // RGBA (32-bit)
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
