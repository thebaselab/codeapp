//
//  ServerCell.swift
//  Code
//
//  Created by Ken Chung on 11/4/2022.
//

import LocalAuthentication
import SwiftUI

struct ServerCell: View {

    @EnvironmentObject var App: MainApp
    @State var url: URL
    @State var showsPrompt = false

    let onRemove: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "server.rack")
                .foregroundColor(.gray)
            Text(url.host ?? "")
            Spacer()
            if App.workSpaceStorage.currentDirectory.url == url.absoluteString {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10)
            }
            if let scheme = RemoteType.type.init(rawValue: url.scheme!) {
                RemoteType(type: scheme)
            }

        }.onTapGesture {

            if KeychainAccessor.shared.hasCredentials(for: url) {
                let context = LAContext()
                context.localizedCancelTitle = "Enter Credentials"
                context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "Authenticate to \(url.host ?? "server")"
                ) { success, error in
                    if success {

                        let cred = KeychainAccessor.shared.getCredentials(for: url)!

                        App.workSpaceStorage.connectToServer(host: url, credentials: cred) {
                            error in
                            if let error = error {
                                DispatchQueue.main.async {
                                    App.notificationManager.showErrorMessage(
                                        error.localizedDescription)
                                }
                            } else {
                                App.notificationManager.showInformationMessage(
                                    "Connected successfully.")
                            }
                        }

                    } else {
                        DispatchQueue.main.async {
                            showsPrompt = true
                        }
                    }
                }
            } else {
                showsPrompt = true
            }

        }.sheet(isPresented: $showsPrompt) {
            RemoteAuthView(targetURL: url) { username, password in
                let cred = URLCredential(
                    user: username, password: password, persistence: .forSession)
                App.workSpaceStorage.connectToServer(host: url, credentials: cred) { error in
                    if let error = error {
                        App.notificationManager.showErrorMessage(error.localizedDescription)
                    }
                    showsPrompt = false
                }
            }
        }.contextMenu {
            Button {
                onRemove()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
