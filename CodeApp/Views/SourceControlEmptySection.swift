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
                Text("Source Control")
                .foregroundColor(Color.init("BW"))
        ) {
            VStack(alignment: .leading) {
                DescriptionText(
                    "The folder currently opened doesn't have a git repository."
                )
                .frame(height: 60)

                SideBarButton("Initialize Repository") {
                    Task {
                        try await onInitializeRepository()
                    }
                }

            }
        }
    }
}
