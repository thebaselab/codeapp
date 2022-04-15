//
//  RepositoryView.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import StoreKit
import SwiftUI

struct RepositoryView: View {

    @EnvironmentObject var App: MainApp
    @AppStorage("userHasPromptedWithReviewRequest") var userHasPromptedWithReviewRequest = false

    @State var showsIdentitySheet: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            if App.commitMessage.isEmpty {
                Text("Message (⌘Enter to commit)").font(.system(size: 14))
                    .foregroundColor(.gray).padding(.leading, 3)
            }
            TextEditor(text: $App.commitMessage)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .frame(minHeight: 35)
        .padding(.horizontal, 7).padding(.top, 1)
        .background(Color.init(id: "input.background"))
        .cornerRadius(15)

        HStack {
            if App.indexedResources.isEmpty {
                Text("There are no staged changes.").foregroundColor(.gray).font(
                    .system(size: 12, weight: .light))
            } else {
                Text(
                    "Commit \(App.indexedResources.count) file\(App.indexedResources.count > 1 ? "s" : "") on '\(App.branch)'..."
                ).foregroundColor(.gray).font(.system(size: 12, weight: .light))
            }

            Spacer()
            Button(action: {
                if let provider = App.workSpaceStorage.gitServiceProvider,
                    provider.requiresSignature
                {
                    showsIdentitySheet.toggle()
                } else if App.gitTracks.isEmpty {
                    App.notificationManager.showWarningMessage(
                        "There are no staged changes")
                } else if App.commitMessage.isEmpty {
                    App.notificationManager.showWarningMessage(
                        "Commit message cannot be empty")
                } else {
                    App.workSpaceStorage.gitServiceProvider?.commit(
                        message: App.commitMessage,
                        error: {
                            App.notificationManager.showErrorMessage(
                                $0.localizedDescription)
                        }
                    ) {
                        App.git_status()
                        DispatchQueue.main.async {
                            App.commitMessage = ""
                            App.monacoInstance.invalidateDecorations()
                        }
                        App.notificationManager.showInformationMessage(
                            "Commit succeeded")
                    }
                }
            }) {
                Image(systemName: "checkmark.circle")
            }
            .buttonStyle(NoAnim())
            .keyboardShortcut(.return, modifiers: [.command])
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .hoverEffect(.highlight)
            .font(.system(size: 16))
            .foregroundColor(Color.init(id: "activityBar.foreground"))

            Menu {
                Section {
                    //                                Button(action: {App.pullRepository()}){
                    //                                    Label("Pull", systemImage: "square.and.arrow.down")
                    //                                }
                    Button(action: {
                        App.notificationManager.showInformationMessage(
                            "Pushing to remote")
                        App.workSpaceStorage.gitServiceProvider?.push(error: {
                            App.notificationManager.showErrorMessage(
                                $0.localizedDescription)
                        }) {
                            App.notificationManager.showInformationMessage(
                                "Push succeeded")
                            App.git_status()

                            DispatchQueue.main.async {
                                if !userHasPromptedWithReviewRequest,
                                    let scene = UIApplication.shared.connectedScenes
                                        .first(where: {
                                            $0.activationState == .foregroundActive
                                        }) as? UIWindowScene
                                {
                                    SKStoreReviewController.requestReview(in: scene)
                                    userHasPromptedWithReviewRequest = true
                                }
                            }

                        }
                    }) {
                        Label("Push", systemImage: "square.and.arrow.up")
                    }
                    //                                Button(action: {App.syncRepository()}){
                    //                                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    //                                }
                    Button(action: {
                        App.notificationManager.showInformationMessage(
                            "Fetching from origin")
                        App.workSpaceStorage.gitServiceProvider?.fetch(error: {
                            App.notificationManager.showErrorMessage(
                                $0.localizedDescription)
                        }) {
                            App.notificationManager.showInformationMessage(
                                "Fetch succeeded")
                            App.git_status()
                        }
                    }) {
                        Label("Fetch", systemImage: "square.and.arrow.down")
                    }
                }

                Section {
                    Button(action: {
                        let path = App.workingResources.keys.map {
                            $0.absoluteString.removingPercentEncoding!
                        }
                        guard path.count > 0 else {
                            return
                        }
                        do {
                            try App.workSpaceStorage.gitServiceProvider?.stage(
                                paths: path)
                            App.git_status()
                        } catch {
                            App.notificationManager.showErrorMessage(
                                error.localizedDescription)
                        }
                    }) {
                        Label("Stage All Changes", systemImage: "plus.circle")
                    }
                    //                                Button(action: {}){
                    //                                    Label(NSLocalizedString("Commit Staged", comment: ""), systemImage: "square.and.arrow.down")
                    //                                }
                    //                                Button(action: {}){
                    //                                    Label(NSLocalizedString("Commit All", comment: ""), systemImage: "square.and.arrow.up")
                    //                                }
                    //                                Button(action: {}){
                    //                                    Label(NSLocalizedString("Revert Last Commit", comment: ""), systemImage: "square.and.arrow.up")
                    //                                }
                }
                //                            Menu{
                //
                //                            }label: {
                //                                Label("Commit...", systemImage: "ellipsis")
                //                            }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .hoverEffect(.highlight)
                    .font(.system(size: 16))
                    .foregroundColor(Color.init(id: "activityBar.foreground"))
            }

        }.sheet(isPresented: $showsIdentitySheet) {
            NavigationView {
                name_email()
            }
        }

    }
}
