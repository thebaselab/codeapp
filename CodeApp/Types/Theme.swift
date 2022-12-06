//
//  Theme.swift
//  Code
//
//  Created by Ken Chung on 7/11/2022.
//

import SwiftUI

struct Theme {
    let id = UUID()
    let name: String
    let url: URL
    let isDark: Bool
    // editor.background, activitybar.background, statusbar_background, sidebar_background
    let preview: (Color, Color, Color, Color)

    lazy var data: Data = {
        try! Data(contentsOf: url)
    }()

    lazy var dictionary: [String: Any] = {
        try! JSONSerialization.jsonObject(with: data, options: .allowFragments)
            as! [String: Any]
    }()

    lazy var jsonString: String = {
        String(data: data, encoding: .utf8)!
    }()
}
