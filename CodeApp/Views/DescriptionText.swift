//
//  DescriptionTextView.swift
//  Code
//
//  Created by Ken Chung on 11/4/2022.
//

import SwiftUI

struct DescriptionText: View {

    var text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .foregroundColor(.gray)
            .font(.system(size: 12, weight: .light))
    }

}
