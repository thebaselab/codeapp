//
//  EditorImplemenationView.swift
//  Code
//
//  Created by Ken Chung on 01/02/2024.
//

import Runestone
import SwiftUI

struct EditorImplementationView: View {
    var implementation: EditorImplementation
    @AppStorage("editorOptions") var editorOptions: CodableWrapper<EditorOptions> = .init(
        value: EditorOptions())

    var body: some View {
        _EditorImplementationView(implementation: implementation)
            .onChange(of: editorOptions) { newValue in
                implementation.options = newValue.value
            }
    }
}

private struct _EditorImplementationView: UIViewRepresentable {
    var implementation: EditorImplementation

    @EnvironmentObject var App: MainApp

    func makeUIView(context: Context) -> UIView {
        return implementation.view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        return
    }
}
