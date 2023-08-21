//
//  CheckoutMenu.swift
//  Code
//
//  Created by Ken Chung on 15/8/2023.
//

import SwiftGit2
import SwiftUI

struct CheckoutMenu: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var stateManager: MainStateManager

    func checkout(destination: CheckoutDestination) async throws {
        guard let gitServiceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }
        do {
            try await gitServiceProvider.checkout(reference: destination.reference)
            App.updateGitRepositoryStatus()
            App.notificationManager.showInformationMessage("Checkout succeeded")
        } catch {
            App.notificationManager.showErrorMessage(error.localizedDescription)
            throw error
        }
    }

    func iconNameForReferenceType(_ reference: ReferenceType) -> String {
        if reference is TagReference {
            return "tag"
        } else if let reference = reference as? Branch {
            return (reference.isRemote ? "cloud" : "arrow.triangle.branch")
        }
        return "circle"
    }

    var body: some View {
        Group {
            if !App.stateManager.availableCheckoutDestination.isEmpty {
                MenuButtonView(
                    options: App.stateManager.availableCheckoutDestination.map {
                        .init(
                            value: $0, title: "\($0.name) at \($0.shortOID)",
                            iconSystemName: iconNameForReferenceType($0.reference))
                    },
                    onSelect: { destination in
                        if !App.gitTracks.isEmpty {

                            App.alertManager.showAlert(
                                title: "Git checkout: Uncommitted Changes",
                                message:
                                    "Uncommited changes will be lost. Do you wish to proceed?",
                                content: AnyView(
                                    Group {
                                        Button("Checkout", role: .destructive) {
                                            Task {
                                                try await checkout(destination: destination)
                                            }
                                        }
                                        Button("common.cancel", role: .cancel) {}
                                    }
                                )
                            )
                        } else {
                            Task {
                                try await checkout(destination: destination)
                            }
                        }
                    }, title: App.branch, iconName: "arrow.triangle.branch",
                    menuTitle: "source_control.checkout.select_branch_or_tag"
                )
            } else {
                EmptyView()
            }
        }.fixedSize(horizontal: true, vertical: false)

    }
}
