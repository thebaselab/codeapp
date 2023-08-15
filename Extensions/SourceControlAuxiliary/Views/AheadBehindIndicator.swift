//
//  AheadBehindIndicator.swift
//  Code
//
//  Created by Ken Chung on 15/8/2023.
//

import SwiftUI

struct AheadBehindIndicator: View {

    @EnvironmentObject var App: MainApp

    var body: some View {
        if let aheadBehind = App.aheadBehind {
            Text("\(aheadBehind.1)↓ \(aheadBehind.0)↑").font(
                .system(size: 12)
            )
        } else {
            EmptyView()
        }
    }
}
