//
//  gitCell.swift
//  Code App
//
//  Created by Ken Chung on 8/12/2020.
//

import SwiftGit2
import SwiftUI

struct SourceControlEntry: View {
    @EnvironmentObject var App: MainApp
    @State var itemUrl: URL
    @State var isIndex: Bool

    let onUnstage: (String) throws -> Void
    let onRevert: (String, Bool) async throws -> Void
    let onStage: ([String]) throws -> Void
    let onShowChangesInDiffEditor: (String) throws -> Void

    var body: some View {
        Button(action: {
            if !isIndex,
                let status =
                    (isIndex ? App.indexedResources[itemUrl] : App.workingResources[itemUrl]),
                status != .workTreeNew
            {
                try? onShowChangesInDiffEditor(itemUrl.absoluteString)
            }
        }) {
            ZStack {

                if itemUrl == (App.activeEditor as? EditorInstanceWithURL)?.url {
                    Color.init(id: "list.inactiveSelectionBackground").cornerRadius(10.0)
                }

                HStack {
                    FileIcon(
                        url: itemUrl.absoluteString, iconSize: 14
                    )

                    if let status =
                        (isIndex ? App.indexedResources[itemUrl] : App.workingResources[itemUrl])
                    {
                        Text(itemUrl.lastPathComponent)
                            .font(.subheadline)
                        Spacer()
                        Controls(
                            status: status, itemUrl: itemUrl, onUnstage: onUnstage,
                            onRevert: onRevert, onStage: onStage)
                        Text(status.symbol)
                            .foregroundColor(Color.init("git.added"))
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 5)
                    } else {
                        Spacer()
                    }

                }.padding(5)
            }
        }.buttonStyle(NoAnim())
    }
}

private struct Controls: View {
    @EnvironmentObject var App: MainApp

    let status: Diff.Status
    let itemUrl: URL
    let onUnstage: (String) throws -> Void
    let onRevert: (String, Bool) async throws -> Void
    let onStage: ([String]) throws -> Void

    var body: some View {
        switch status {
        case .indexModified, .indexNew, .indexDeleted:
            Image(systemName: "minus")
                .padding(2)
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .onTapGesture {
                    try? onUnstage(itemUrl.absoluteString)
                }
                .hoverEffect(.highlight)
        case .workTreeModified, .workTreeNew, .workTreeDeleted:
            if status != .workTreeNew {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12))
                    .padding(2)
                    .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .onTapGesture {
                        Task {
                            try await onRevert(itemUrl.absoluteString, false)
                        }
                    }
                    .hoverEffect(.highlight)
            }
            Image(systemName: "plus")
                .padding(2)
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .onTapGesture {
                    try? onStage([itemUrl.absoluteString])
                }
                .hoverEffect(.highlight)
        default:
            Spacer()
        }
    }
}

extension Diff.Status {
    var backgroundColor: Color {
        switch self {
        case .workTreeModified, .indexModified:
            return Color.init("git.modified")
        case .workTreeNew:
            return Color.init("git.untracked")
        case .workTreeDeleted, .indexDeleted:
            return Color.init("git.deleted")
        case .indexNew:
            return Color.init("git.added")
        default:
            return Color.init("BW")
        }
    }

    var symbol: String {
        switch self {
        case .workTreeModified, .indexModified:
            return "M"
        case .workTreeNew:
            return "U"
        case .workTreeDeleted, .indexDeleted:
            return "D"
        case .indexNew:
            return "A"
        default:
            return "X"
        }
    }
}
