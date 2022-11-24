//
//  SearchResultsSection.swift
//  Code
//
//  Created by Ken Chung on 15/4/2022.
//

import SwiftUI

struct SearchResultsSection: View {

    @EnvironmentObject var App: MainApp

    let onTapSearchResult: (SearchResult, URL) -> Void

    private func binding(for key: String) -> Binding<Bool> {
        return .init(
            get: { App.textSearchManager.expansionStates[key, default: false] },
            set: { App.textSearchManager.expansionStates[key] = $0 })
    }

    var body: some View {
        Section(
            header:
                HStack {
                    Text("Results")
                    Text(" " + App.textSearchManager.message)
                }.foregroundColor(Color(id: "sideBarSectionHeader.foreground"))
        ) {
            if let mainFolderUrl = URL(string: App.workSpaceStorage.currentDirectory.url) {
                ForEach(Array(App.textSearchManager.results.keys.sorted()), id: \.self) {
                    key in
                    let fileURL = URL(fileURLWithPath: key)

                    if let result = App.textSearchManager.results[key] {
                        DisclosureGroup(
                            isExpanded: binding(for: key),
                            content: {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(result) { res in
                                        HighlightedText(
                                            res.line.trimmingCharacters(
                                                in: .whitespacesAndNewlines),
                                            matching: App.textSearchManager.searchTerm,
                                            accentColor: Color.init(id: "statusBar.background")
                                        )
                                        .foregroundColor(Color.init("T1"))
                                        .font(.custom("Menlo Regular", size: 14))
                                        .lineLimit(1)
                                        .onTapGesture {
                                            onTapSearchResult(res, fileURL)
                                        }
                                    }
                                }
                            },
                            label: {
                                VStack(alignment: .leading) {
                                    HStack {
                                        FileIcon(url: key, iconSize: 10)
                                        Text(fileURL.lastPathComponent + " ")
                                            .font(.subheadline)
                                            .foregroundColor(Color.init("T1"))
                                        Circle()
                                            .fill(Color.init("panel.border"))
                                            .frame(width: 14, height: 14)
                                            .overlay(
                                                Text("\(result.count)").foregroundColor(
                                                    Color.init("T1")
                                                ).font(.system(size: 10))
                                            )
                                    }
                                    if let path = fileURL.deletingLastPathComponent()
                                        .relativePath(from: mainFolderUrl),
                                        !path.isEmpty
                                    {
                                        Text(path)
                                            .foregroundColor(.gray)
                                            .font(.system(size: 10, weight: .light))
                                    }

                                }
                            })
                    }
                }
            }
        }
    }
}
