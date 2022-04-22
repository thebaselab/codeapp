//
//  searchBar.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

struct SearchBar: View {

    @Binding var text: String
    @State private var isEditing = false
    let searchAction: (() -> Void)?
    var clearAction: (() -> Void)? = nil
    let placeholder: String
    let cornerRadius: CGFloat?

    var body: some View {
        HStack {

            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.subheadline)

            TextField(placeholder, text: $text, onCommit: { searchAction?() })
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .overlay(
                    HStack {
                        Spacer()

                        if isEditing && text != "" {
                            Image(systemName: "multiply.circle.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 8)
                                .highPriorityGesture(
                                    TapGesture()
                                        .onEnded({
                                            self.text = ""
                                            clearAction?()
                                        })
                                )
                        }
                    }
                )
                .onTapGesture {
                    self.isEditing = true
                }

        }.padding(7)
            .background(Color.init(id: "input.background"))
            .cornerRadius(cornerRadius ?? 15)
    }
}
