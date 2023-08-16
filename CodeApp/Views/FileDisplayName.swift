//
//  FileDisplayName.swift
//  Code
//
//  Created by Ken Chung on 19/4/2022.
//

import SwiftGit2
import SwiftUI

struct FileDisplayName: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme
    let gitStatus: Diff.Status?
    let name: String
    let withSpacer: Bool

    init(gitStatus: Diff.Status?, name: String, useAllSpaceAvailableHorizontally: Bool = true) {
        self.gitStatus = gitStatus
        self.name = name
        self.withSpacer = useAllSpaceAvailableHorizontally
    }

    var body: some View {
        HStack {
            if let status = gitStatus {
                Group {
                    Text(name)
                    if withSpacer {
                        Spacer()
                    }
                    Text(status.symbol)
                }
                .font(.subheadline)
                .foregroundColor(status.backgroundColor)
            } else {
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(Color.init(id: "list.inactiveSelectionForeground"))
            }

        }
    }
}
