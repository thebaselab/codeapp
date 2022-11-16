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

    func statusToDisplay(status: Diff.Status) -> String {
        switch status {
        case .workTreeModified, .indexModified:
            return "M"
        case .workTreeNew:
            return "U"
        case .workTreeDeleted, .indexDeleted:
            return "D"
        case .indexNew:
            return "A"
        default:
            return ""
        }
    }

    func statusToColor(status: Diff.Status) -> Color {
        switch status {
        case .workTreeModified, .indexModified:
            return Color.init("git.modified")
        case .workTreeNew:
            return Color.init("git.untracked")
        case .workTreeDeleted, .indexDeleted:
            return Color.init("git.deleted")
        case .indexNew:
            return Color.init("git.added")
        default:
            return Color.init(id: "list.inactiveSelectionForeground")
        }
    }

    var body: some View {
        HStack {
            if let status = gitStatus {
                Group {
                    Text(name)
                    Spacer()
                    Text(statusToDisplay(status: status))
                }
                .font(.subheadline)
                .foregroundColor(statusToColor(status: status))
            } else {
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(Color.init(id: "list.inactiveSelectionForeground"))
            }

        }
    }
}
