//
//  bottomBar.swift
//  Code
//
//  Created by Ken Chung on 1/7/2021.
//

import SwiftGit2
import SwiftUI

struct BottomBar: View {

    @EnvironmentObject var App: MainApp

    @State var currentLine = 0
    @State var currentColumn = 0

    @AppStorage("editorReadOnly") var editorReadOnly = false
    @SceneStorage("panel.visible") var isPanelVisible: Bool = DefaultUIState.PANEL_IS_VISIBLE

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    let openConsolePanel: () -> Void
    let onDirectoryPickerFinished: () -> Void

    func checkout(destination: CheckoutDestination) async throws {
        guard let gitServiceProvider = App.workSpaceStorage.gitServiceProvider else {
            throw SourceControlError.gitServiceProviderUnavailable
        }
        do {
            try await gitServiceProvider.checkout(oid: destination.reference.oid)
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
        ZStack(alignment: .center) {
            Color.init(id: "statusBar.background").frame(maxHeight: 20)
            HStack {
                HStack {
                    if App.workSpaceStorage.remoteConnected {
                        HStack {
                            Image(systemName: "rectangle.connected.to.line.below")
                                .font(.system(size: 10))
                            Text(App.workSpaceStorage.remoteHost ?? "")
                        }
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 3)
                    }

                    if (App.branch) != "" {
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
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(height: 20)

                        if let aheadBehind = App.aheadBehind {
                            Text("\(aheadBehind.1)↓ \(aheadBehind.0)↑").font(
                                .system(size: 12)
                            )
                        }
                    }
                    // TODO: Display image dimension information
                    //                    if let activeEditor = App.activeEditor, activeEditor.type == .image,
                    //                        let imageURL = URL(string: activeEditor.url),
                    //                        let uiImage = UIImage(contentsOfFile: imageURL.path)
                    //                    {
                    //                        Text(
                    //                            "\(activeEditor.url.components(separatedBy: ".").last?.uppercased() ?? "") \(String(describing: Int(uiImage.size.width * uiImage.scale)))x\(String(describing: Int(uiImage.size.height * uiImage.scale)))"
                    //                        )
                    //                    }
                }.padding(.leading, [UIApplication.shared.getSafeArea(edge: .bottom), 5].max())

                Spacer()

                HStack {

                    if App.activeEditor is TextEditorInstance {

                        Text("Ln \(String(currentLine)), Col \(String(currentColumn))")
                            .onTapGesture {
                                App.monacoInstance.executeJavascript(
                                    command:
                                        "editor.focus();editor.trigger('', 'editor.action.gotoLine')"
                                )
                            }
                            .onReceive(
                                NotificationCenter.default.publisher(
                                    for: Notification.Name("monaco.cursor.position.changed"),
                                    object: nil),
                                perform: { notification in
                                    guard
                                        let sceneIdentifier =
                                            notification.userInfo?["sceneIdentifier"] as? UUID,
                                        sceneIdentifier == App.sceneIdentifier
                                    else { return }

                                    currentLine = notification.userInfo?["lineNumber"] as! Int
                                    currentColumn = notification.userInfo?["column"] as! Int
                                })

                        if editorReadOnly {
                            Text("READ-ONLY")
                        }

                        if let editor = (App.activeEditor as? TextEditorInstance) {
                            EncodingMenu(editor: editor)
                        }
                    }
                }
                .frame(maxHeight: 20)
                .padding(.trailing, [UIApplication.shared.getSafeArea(edge: .bottom), 5].max())
            }
        }
        .font(.system(size: 12))
        .foregroundColor(Color.init(id: "statusBar.foreground"))
    }
}
