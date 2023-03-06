//
//  RemoteTypeLabel.swift
//  Code
//
//  Created by Ken Chung on 11/4/2022.
//

import SwiftUI

struct RemoteTypeLabel: View {
    let type: RemoteType

    var body: some View {
        Text(type == .sftp ? "SSH" : type.rawValue.uppercased())
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(Color.gray)
            .padding(2)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.gray, lineWidth: 1)
            )
    }
}
