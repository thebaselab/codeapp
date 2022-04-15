//
//  Button.swift
//  Code
//
//  Created by Ken Chung on 11/4/2022.
//

import SwiftUI

struct SideBarButton: View {

    @State var title: String
    let onTap: () -> Void

    init(_ title: String, onTapGesture: @escaping () -> Void) {
        self._title = State.init(initialValue: title)
        self.onTap = onTapGesture
    }

    var body: some View {
        HStack {
            Spacer()
            Text(title)
                .lineLimit(1)
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .light))
            Spacer()
        }.onTapGesture {
            onTap()
        }.foregroundColor(Color.init("T1"))
            .padding(4)
            .background(
                Color.init(id: "button.background")
            ).cornerRadius(10.0)
    }
}
