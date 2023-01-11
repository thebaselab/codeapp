//
//  GitHubSearchView.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import SwiftUI

struct GitHubSearchView: View {

    @EnvironmentObject var App: MainApp

    let onClone: (String) async throws -> Void

    var body: some View {
        SearchBar(
            text: $App.searchManager.searchTerm,
            searchAction: { App.searchManager.search() }, placeholder: "GitHub",
            cornerRadius: 15)

        ForEach(App.searchManager.searchResultItems, id: \.html_url) { item in
            GitHubSearchResultCell(item: item, onClone: onClone)
        }.listRowBackground(Color.init(id: "sideBar.background"))
    }
}

struct GitHubSearchResultCell: View {

    @State var item: GitHubSearchManager.item

    let onClone: (String) async throws -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                RemoteImage(url: item.owner.avatar_url)
                    .frame(width: 20, height: 20)
                    .cornerRadius(5)
                Text(item.owner.login)
                    .font(.system(size: 12))
                    .foregroundColor(Color.init("T1"))

                Spacer()

                Image(systemName: "hand.raised")
                    .font(.system(.caption))
                    .foregroundColor(.gray)
                    .onTapGesture {
                        let url = URL(
                            string:
                                "https://support.github.com/contact/report-abuse?category=report-abuse&report=other&report_type=unspecified"
                        )!
                        UIApplication.shared.open(url)
                    }
            }

            Text(item.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color.init("T1"))

            if item.description != nil {
                Text(item.description!)
                    .font(.subheadline)
                    .foregroundColor(Color.init("T1"))
            }

            HStack {
                Image(systemName: "star")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                DescriptionText("\(item.stargazers_count)")

                if item.language != nil {
                    DescriptionText(
                        "\(item.language ?? "")  • \(humanReadableByteCount(bytes: item.size*1024))"
                    )
                } else {
                    DescriptionText("\(humanReadableByteCount(bytes: item.size*1024))")
                }

                Spacer()

                CloneButton(item: item, onClone: onClone)
            }
        }
    }
}

private struct CloneButton: View {

    @EnvironmentObject var App: MainApp
    @State var item: GitHubSearchManager.item

    let onClone: (String) async throws -> Void

    var body: some View {
        Text("source_control.clone")
            .foregroundColor(.white)
            .lineLimit(1)
            .font(.system(size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Color.init(id: "button.background")
            )
            .cornerRadius(10)
            .onTapGesture {
                Task {
                    try await onClone(item.clone_url)
                }
            }

    }
}
