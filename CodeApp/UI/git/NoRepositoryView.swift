//
//  NoRepositoryView.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import SwiftUI

struct NoRepositoryView: View {

    @EnvironmentObject var App: MainApp

    var body: some View {
        VStack {
            DescriptionText(
                "The folder currently opened doesn't have a git repository."
            )
            .frame(height: 60)

            SideBarButton("Initialize Repository") {

                App.workSpaceStorage.gitServiceProvider?.initialize(error: { err in
                    DispatchQueue.main.async {
                        App.notificationManager.showErrorMessage(
                            err.localizedDescription)
                    }
                }) {
                    DispatchQueue.main.async {
                        App.notificationManager.showInformationMessage(
                            "Repository initialized")
                    }
                    App.git_status()
                }
            }

        }
    }
}
