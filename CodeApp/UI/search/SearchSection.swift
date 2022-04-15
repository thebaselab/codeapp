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

    var body: some View {
        Section(
            header:
                Text("Search", comment: "")
                .foregroundColor(Color.init("BW"))
        ) {
            SearchBar(
                text: $App.textSearchManager.searchTerm,
                searchAction: {
                    if let path = URL(string: App.workSpaceStorage.currentDirectory.url)?
                        .path
                    {
                        App.textSearchManager.search(
                            str: App.textSearchManager.searchTerm, path: path)
                    }
                },
                clearAction: {
                    App.textSearchManager.removeAllResults()
                }, placeholder: NSLocalizedString("Search", comment: ""), cornerRadius: 15
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
