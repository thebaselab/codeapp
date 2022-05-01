//
//  DescriptionTextView.swift
//  Code
//
//  Created by Ken Chung on 11/4/2022.
//

import SwiftUI

struct DescriptionText: View {

    @State var text: String

    init(_ text: String) {
        self._text = State.init(initialValue: text)
    }

    var body: some View {
        Text(NSLocalizedString(text, comment: ""))
            .foregroundColor(.gray)
            .font(.system(size: 12, weight: .light))
            .lineLimit(3)
    }

}
