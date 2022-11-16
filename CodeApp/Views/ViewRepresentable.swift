//
//  ViewRepresentable.swift
//  Code
//
//  Created by Ken Chung on 8/6/2021.
//

import SwiftUI

struct ViewRepresentable: UIViewRepresentable {

    private var uiView: UIView

    init(_ uiView: UIView) {
        self.uiView = uiView
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        return
    }

    func makeUIView(context: Context) -> some UIView {
        return uiView
    }
}
