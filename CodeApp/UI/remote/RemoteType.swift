//
//  RemoteType.swift
//  Code
//
//  Created by Ken Chung on 11/4/2022.
//

import SwiftUI

struct RemoteType: View {

    enum type: String, CaseIterable, Identifiable {
        case sftp
        case ftp
        case ftps
        var id: String { self.rawValue }
    }

    @State var badgeType: type

    init(type: type) {
        self.badgeType = type
    }

    var body: some View {
        Text(badgeType.rawValue.uppercased())
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(Color.gray)
            .padding(2)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.gray, lineWidth: 1)
            )
    }
}
