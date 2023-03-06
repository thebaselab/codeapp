//
//  RemoteContainer.swift
//  RemoteContainer
//
//  Created by Ken Chung on 8/8/2021.
//

import FilesProvider
import LocalAuthentication
import SwiftUI

struct RemoteContainer: View {

    @EnvironmentObject var App: MainApp
    @State var hosts: [RemoteHost]

    init() {
        hosts = UserDefaults.standard.remoteHosts
    }

    func onSaveCredentialsForHost(for host: RemoteHost, cred: URLCredential) throws {
        guard let username = cred.user, let password = cred.password else {
            throw RemoteHostError.invalidCredentials
        }

        KeychainAccessor.shared.storeCredentials(
            username: username, password: password,
            for: host.url)
    }

    func onSaveHost(host: RemoteHost) {
        _ = KeychainAccessor.shared.removeCredentials(
            for: host.url)

        var remoteHosts = UserDefaults.standard.remoteHosts
        remoteHosts = remoteHosts.filter { $0.url != host.url }
        remoteHosts.append(host)
        UserDefaults.standard.remoteHosts = remoteHosts

        DispatchQueue.main.async {
            hosts = remoteHosts
        }
    }

    func onRemoveHost(host: RemoteHost) {
        _ = KeychainAccessor.shared.removeCredentials(for: host.url)
        if let keyChainId = host.privateKeyContentKeychainID {
            _ = KeychainAccessor.shared.removeObjectForKey(for: keyChainId)
        }

        DispatchQueue.main.async {
            hosts.removeAll(where: { $0.url == host.url })
            UserDefaults.standard.remoteHosts = hosts
        }
    }

    func onRenameHost(host: RemoteHost, name: String) {
        guard let hostIndexToModify = hosts.firstIndex(where: { $0.url == host.url }) else {
            return
        }
        hosts[hostIndexToModify].displayName = name.isEmpty ? nil : name
        UserDefaults.standard.remoteHosts = hosts
    }

    func onConnectToHost(host: RemoteHost, onRequestCredentials: () -> Void) async throws {
        guard let hostUrl = URL(string: host.url) else {
            throw RemoteHostError.invalidUrl
        }

        guard KeychainAccessor.shared.hasCredentials(for: host.url) else {
            onRequestCredentials()
            return
        }

        let context = LAContext()
        context.localizedCancelTitle = "Enter Credentials"

        let biometricAuthSuccess = try? await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Authenticate to \(hostUrl.host ?? "server")")

        guard biometricAuthSuccess == true else {
            onRequestCredentials()
            return
        }

        guard let cred = KeychainAccessor.shared.getCredentials(for: host.url) else {
            throw WorkSpaceStorage.FSError.AuthFailure
        }

        try await onConnectToHostWithCredentials(host: host, cred: cred)
    }

    func onConnectToHostWithCredentials(
        host: RemoteHost, cred: URLCredential
    ) async throws {
        guard let hostUrl = URL(string: host.url) else {
            throw RemoteHostError.invalidUrl
        }

        var authenticationMode: RemoteAuthenticationMode

        if host.useKeyAuth {
            // Legacy in-file id_rsa authentication
            authenticationMode = .inFileSSHKey(cred, nil)
        } else if let keyContentId = host.privateKeyContentKeychainID {
            guard let keyContent = KeychainAccessor.shared.getObjectString(for: keyContentId) else {
                throw WorkSpaceStorage.FSError.AuthFailure
            }
            authenticationMode = .inMemorySSHKey(cred, keyContent)
        } else {
            authenticationMode = .plainUsernamePassword(cred)
        }

        try await App.notificationManager.withAsyncNotification(
            title: "remote.connecting",
            task: {
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, Error>) in
                    App.workSpaceStorage.connectToServer(
                        host: hostUrl, authenticationMode: authenticationMode
                    ) {
                        error in
                        if let error = error {
                            DispatchQueue.main.async {
                                App.notificationManager.showErrorMessage(
                                    error.localizedDescription)
                            }
                            continuation.resume(throwing: error)
                        } else {
                            App.loadRepository(url: hostUrl)
                            App.notificationManager.showInformationMessage(
                                "remote.connected")
                            App.terminalInstance.terminalServiceProvider =
                                App.workSpaceStorage.terminalServiceProvider
                            continuation.resume(returning: ())
                        }
                    }
                }
            }
        )
    }

    var body: some View {
        List {
            Group {
                if App.workSpaceStorage.remoteConnected {
                    RemoteConnectedSection()
                } else {
                    RemoteListSection(
                        hosts: hosts, onRemoveHost: onRemoveHost, onConnectToHost: onConnectToHost,
                        onConnectToHostWithCredentials: onConnectToHostWithCredentials,
                        onRenameHost: onRenameHost)
                    RemoteCreateSection(
                        hosts: hosts,
                        onConnectToHostWithCredentials: onConnectToHostWithCredentials,
                        onSaveHost: onSaveHost, onSaveCredentialsForHost: onSaveCredentialsForHost)
                }

            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

        }.listStyle(SidebarListStyle())
    }
}
