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

    private func injectBarButtons(textView: TextView) {
        let toolbar = UIHostingController(
            rootView: EditorKeyboardToolBar(isMonaco: false).environmentObject(App))
        toolbar.view.frame = CGRect(
            x: 0, y: 0, width: (textView.bounds.width), height: 40)
        textView.inputAccessoryView = toolbar.view
    }

    private func injectBarButtons(webView: WebViewBase) {
        let toolbar = UIHostingController(
            rootView: EditorKeyboardToolBar(isMonaco: true).environmentObject(App))
        toolbar.view.frame = CGRect(
            x: 0, y: 0, width: (webView.bounds.width), height: 40)
        webView.addInputAccessoryView(toolbar: toolbar.view)
    }

    func makeUIView(context: Context) -> UIView {
        if let webView = implementation.view as? WebViewBase {
            if implementation.options.toolBarEnabled {
                injectBarButtons(webView: webView)
            } else {
                webView.addInputAccessoryView(toolbar: UIView.init())
            }
        } else if let textView = implementation.view as? TextView {
            if implementation.options.toolBarEnabled {
                injectBarButtons(textView: textView)
            }
        }
        return implementation.view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        return
    }
}
