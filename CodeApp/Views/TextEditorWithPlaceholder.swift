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

    init(placeholder: String, text: Binding<String>) {
        _text = text
        _placeholder = State(initialValue: placeholder)
    }

    var body: some View {
        ZStack {
            if text == "" {
                TextEditor(text: $placeholder).font(
                    .custom("Menlo", size: 13, relativeTo: .footnote)
                ).foregroundColor(.gray).disabled(true)
            }

            TextEditor(text: $text).autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.custom("Menlo", size: 13, relativeTo: .footnote)).onChange(
                    of: text,
                    perform: { newValue in
                        print(newValue)

                    })
        }
    }
}
