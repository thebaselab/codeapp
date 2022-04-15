//
//  GitHubSearchView.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import SwiftUI

struct GitHubSearchView: View {

    @EnvironmentObject var App: MainApp

    var body: some View {
        SearchBar(
            text: $App.searchManager.searchTerm,
            searchAction: { App.searchManager.search() }, placeholder: "GitHub",
            cornerRadius: 15)
        ForEach(App.searchManager.searchResultItems, id: \.html_url) { item in
            GitHubSearchResultCell(item: item)
        }.listRowBackground(Color.init(id: "sideBar.background"))
    }
}
