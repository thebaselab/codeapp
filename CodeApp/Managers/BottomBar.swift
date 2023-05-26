//
//  bottomBar.swift
//  Code
//
//  Created by Ken Chung on 1/7/2021.
//

import SwiftUI

struct BottomBar: View {

    @EnvironmentObject var App: MainApp

    @State var isShowingCheckoutAlert: Bool = false
    @State var selectedBranch: checkoutDest? = nil
    @State var checkoutDetached: Bool = false
    @State var currentLine = 0
    @State var currentColumn = 0

    @AppStorage("editorReadOnly") var editorReadOnly = false
    @SceneStorage("panel.visible") var isPanelVisible: Bool = DefaultUIState.PANEL_IS_VISIBLE

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    let openConsolePanel: () -> Void
    let onDirectoryPickerFinished: () -> Void
    // Somehow it doesn't compile with arguments in the function
    func checkout() {
        switch selectedBranch?.type {
        case .tag:
            App.workSpaceStorage.gitServiceProvider?.checkout(
                tagName: selectedBranch!.name, detached: checkoutDetached,
                error: {
                    App.notificationManager.showErrorMessage($0.localizedDescription)
                }
            ) {
                App.notificationManager.showInformationMessage("Checkout succeeded")
            }

        case .local_branch:
            App.workSpaceStorage.gitServiceProvider?.checkout(
                localBranchName: selectedBranch!.name, detached: checkoutDetached,
                error: {
                    App.notificationManager.showErrorMessage($0.localizedDescription)
                }
            ) {
                App.notificationManager.showInformationMessage("Checkout succeeded")
            }
        case .remote_branch:
            App.workSpaceStorage.gitServiceProvider?.checkout(
                remoteBranchName: selectedBranch!.name, detached: checkoutDetached,
                error: {
                    App.notificationManager.showErrorMessage($0.localizedDescription)
                }
            ) {
                App.notificationManager.showInformationMessage("Checkout succeeded")
            }
        case .none:
            break
        }
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
                        HStack {
                            if let destinations = App.workSpaceStorage.gitServiceProvider?
                                .checkoutDestinations()
                            {
                                MenuButtonView(
                                    options: destinations.map {
                                        .init(
                                            value: $0, title: "\($0.name) at \($0.oid)",
                                            iconSystemName: "arrow.triangle.branch")
                                    },
                                    onSelect: { branch in
                                        selectedBranch = branch
                                        checkoutDetached = false
                                        if !App.gitTracks.isEmpty {
                                            isShowingCheckoutAlert = true
                                        } else {
                                            checkout()
                                        }
                                    }, title: App.branch, iconName: "arrow.triangle.branch")
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(height: 20)
                        .alert(isPresented: $isShowingCheckoutAlert) {
                            Alert(
                                title: Text("Git checkout: Uncommitted Changes"),
                                message: Text(
                                    "Uncommited changes will be lost. Do you wish to proceed?"),
                                primaryButton: .destructive(Text("Checkout")) {
                                    checkout()
                                }, secondaryButton: .cancel())
                        }

                        if App.remote != "" {

                            if App.aheadBehind != nil {
                                Text("\(App.aheadBehind!.1)↓ \(App.aheadBehind!.0)↑").font(
                                    .system(size: 12)
                                )
                            }
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
