//
//  hiddenSystemOverlays.swift
//  Code
//
//  Created by Ken Chung on 05/12/2022.
//

import SwiftUI

extension View {
    @ViewBuilder
    func hiddenSystemOverlays() -> some View {
        if #available(iOS 16, *) {
            self.persistentSystemOverlays(.hidden)
        } else {
            self
        }
    }
}
