//
//  EmptySourceControlView.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import SwiftUI

struct SourceControlEmptySection: View {

    @EnvironmentObject var App: MainApp

    let onInitializeRepository: () async throws -> Void

    var body: some View {
        Section(
            header:
                Text("source_control.title")
                .foregroundColor(Color(id: "sideBarSectionHeader.foreground"))
        ) {
            VStack(alignment: .leading) {
                DescriptionText(
                    "The folder currently opened doesn't have a git repository."
                )

                SideBarButton("Initialize Repository") {
                    Task {
                        try await onInitializeRepository()
                    }
                }

            }
        }
    }
}
