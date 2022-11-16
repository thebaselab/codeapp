//
//  SourceControlCloneSection.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import SwiftUI

struct SourceControlCloneSection: View {

    @EnvironmentObject var App: MainApp
    @State var gitURL: String = ""

    let onClone: (String) async throws -> Void

    var body: some View {
        Section(
            header:
                Text("Clone Repository")
                .foregroundColor(Color(id: "sideBarSectionHeader.foreground"))
        ) {

            if App.searchManager.errorMessage != "" {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(App.searchManager.errorMessage).font(
                        .system(size: 12, weight: .light))
                }.foregroundColor(.gray)
            }

            HStack {
                Image(systemName: "link")
                    .foregroundColor(.gray)
                    .font(.subheadline)

                TextField(
                    "URL (HTTPS)", text: $gitURL,
                    onCommit: {
                        Task {
                            try await onClone(gitURL)
                            await MainActor.run {
                                gitURL = ""
                            }
                        }
                    }
                )
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)

                Spacer()

            }.padding(7)
                .background(Color.init(id: "input.background"))
                .cornerRadius(15)

            DescriptionText("Example: https://github.com/thebaselab/codeapp.git")

            GitHubSearchView(onClone: onClone)
        }
    }
}
