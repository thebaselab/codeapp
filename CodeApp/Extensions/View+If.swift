//
//  View+If.swift
//  uiexperiment
//
//  Created by Ken Chung on 14/3/2021.
//

import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition { transform(self) } else { self }
    }
}
