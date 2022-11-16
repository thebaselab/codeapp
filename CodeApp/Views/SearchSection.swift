//
//  SearchSection.swift
//  Code
//
//  Created by Ken Chung on 14/4/2022.
//

import SwiftUI

struct SearchSection: View {
    @EnvironmentObject var App: MainApp
    @FocusState private var searchBarFocused: Bool

    let onSearch: () -> Void
    let onClearSearchResults: () -> Void

    var body: some View {
        Section(
            header:
                Text("Search", comment: "")
                .foregroundColor(Color(id: "sideBarSectionHeader.foreground"))
        ) {
            SearchBar(
                text: $App.textSearchManager.searchTerm,
                searchAction: onSearch,
                clearAction: onClearSearchResults,
                placeholder: NSLocalizedString("Search", comment: ""), cornerRadius: 15
            )
            .focused($searchBarFocused)
        }.onAppear {
            if App.textSearchManager.results.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    searchBarFocused = true
                }
            }
        }

    }
}
