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
    @State var host: RemoteHost
    @State var showsPrompt = false

    let onRemove: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "server.rack")
                .foregroundColor(.gray)
            if let host = URL(string: host.url)?.host {
                Text(host)
            }
            Spacer()
            if App.workSpaceStorage.currentDirectory.url == host.url {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10)
            }
            if let scheme = URL(string: host.url)?.scheme,
                let type = RemoteType.type.init(rawValue: scheme)
            {
                RemoteType(type: type)
            }

        }.onTapGesture {

            let hostUrl = URL(string: host.url)!

            if KeychainAccessor.shared.hasCredentials(for: host.url) {
                let context = LAContext()
                context.localizedCancelTitle = "Enter Credentials"
                context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "Authenticate to \(hostUrl.host ?? "server")"
                ) { success, error in
                    if success {

                        let cred = KeychainAccessor.shared.getCredentials(for: host.url)!

                        App.workSpaceStorage.connectToServer(
                            host: hostUrl, credentials: cred, usesKey: host.useKeyAuth
                        ) {
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
            RemoteAuthView(host: host) { username, password in
                let cred = URLCredential(
                    user: username, password: password, persistence: .forSession)
                let hostUrl = URL(string: host.url)!
                App.workSpaceStorage.connectToServer(host: hostUrl, credentials: cred) { error in
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
