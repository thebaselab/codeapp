//
//  TextEditorWithPlaceholder.swift
//  Code
//
//  Created by Ben Wu on 17/11/2022.
//
import SwiftUI

struct TextEditorWithPlaceholder: View {

    @Binding var text: String
    @State private var placeholder: String
    let customFont: Font?

    init(placeholder: String, text: Binding<String>, customFont: Font? = nil) {
        _text = text
        _placeholder = State(initialValue: NSLocalizedString(placeholder, comment: ""))
        self.customFont = customFont
    }

    var body: some View {
        ZStack {
            if text.isEmpty {
                TextEditor(text: $placeholder)
                    .foregroundColor(.gray)
                    .disabled(true)
                    .if(customFont != nil) {
                        $0.font(customFont)
                    }
            }

            TextEditor(text: $text)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .if(customFont != nil) {
                    $0.font(customFont)
                }
        }
    }
}
