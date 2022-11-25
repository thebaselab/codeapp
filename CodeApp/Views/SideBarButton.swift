//
//  Button.swift
//  Code
//
//  Created by Ken Chung on 11/4/2022.
//

import SwiftUI

struct NoAnim: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
    }
}

struct SideBarButton: View {

    @State var title: String
    let onTap: () -> Void

    init(_ title: String, onTapGesture: @escaping () -> Void) {
        self._title = State.init(initialValue: title)
        self.onTap = onTapGesture
    }

    var body: some View {

        Button(
            action: {
                onTap()
            },
            label: {
                HStack {
                    Spacer()
                    Text(NSLocalizedString(title, comment: ""))
                        .lineLimit(1)
                        .foregroundColor(.white)
                        .font(.subheadline)
                    Spacer()
                }
                .foregroundColor(Color.init("T1"))
                .padding(4)
                .background(
                    Color.init(id: "button.background")
                )
                .cornerRadius(10.0)
            }
        )
    }
}
