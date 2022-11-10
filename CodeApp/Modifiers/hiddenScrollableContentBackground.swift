//
//  hiddenScrollableContentBackground.swift
//  Code
//
//  Created by Ken Chung on 7/11/2022.
//

import SwiftUI

extension View {
    @ViewBuilder
    func hiddenScrollableContentBackground() -> some View {
        if #available(iOS 16, *) {
            self
                .scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
