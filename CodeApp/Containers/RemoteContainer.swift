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
    @EnvironmentObject var authenticationRequestManager: AuthenticationRequestManager
    @EnvironmentObject var alertManager: AlertManager

    @State var hosts: [RemoteHost] = []

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

    func onRemoveHost(host: RemoteHost, confirm: Bool = false) {
        if !confirm
            && UserDefaults.standard.remoteHosts.contains(where: { $0.jumpServerUrl == host.url })
        {
            alertManager.showAlert(
                title: "remote.confirm_delete_are_you_sure_to_delete",
                message: "remote.one_or_more_hosts_use_this_host_as_jump_proxy",
                content: AnyView(
                    Group {
                        Button("common.delete", role: .destructive) {
                            onRemoveHost(host: host, confirm: true)
                        }
                        Button("common.cancel", role: .cancel) {}
                    }
                ))
        } else {
            _ = KeychainAccessor.shared.removeCredentials(for: host.url)
            if let keyChainId = host.privateKeyContentKeychainID {
                _ = KeychainAccessor.shared.removeObjectForKey(for: keyChainId)
            }

            DispatchQueue.main.async {
                hosts.removeAll(where: { $0.url == host.url })
                UserDefaults.standard.remoteHosts = hosts
            }
        }
    }

    func onRenameHost(host: RemoteHost, name: String) {
        guard let hostIndexToModify = hosts.firstIndex(where: { $0.url == host.url }) else {
            return
        }
        hosts[hostIndexToModify].displayName = name.isEmpty ? nil : name
        UserDefaults.standard.remoteHosts = hosts
    }

    private func requestManualAuthenticationForHost(host: RemoteHost) async throws -> URLCredential
    {
        let hostPasswordPair = try await authenticationRequestManager.requestPasswordAuthentication(
            title: "remote.credentials_for \(host.url)",
            usernameTitleKey: "common.username",
            passwordTitleKey: (host.useKeyAuth || host.privateKeyContentKeychainID != nil
                || host.privateKeyPath != nil)
                ? "remote.passphrase_for_private_key" : "common.password"
        )
        return URLCredential(
            user: hostPasswordPair.0, password: hostPasswordPair.1, persistence: .none)
    }

    private func requestBiometricAuthenticationForHost(host: RemoteHost) async throws
        -> URLCredential
    {
        guard let hostUrl = URL(string: host.url) else {
            throw RemoteHostError.invalidUrl
        }

        let context = LAContext()
        context.localizedCancelTitle = NSLocalizedString("remote.enter_credentials", comment: "")

        guard
            try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: String(
                    format: NSLocalizedString(
                        "remote.authenticate_to %@", comment: ""), hostUrl.host ?? "host"))
        else {
            throw WorkSpaceStorage.FSError.AuthFailure
        }

        guard let cred = KeychainAccessor.shared.getCredentials(for: host.url) else {
            throw WorkSpaceStorage.FSError.AuthFailure
        }
        return cred
    }

    private func requestAuthenticationForHost(host: RemoteHost) async throws -> URLCredential {
        if KeychainAccessor.shared.hasCredentials(for: host.url) {
            do {
                return try await requestBiometricAuthenticationForHost(host: host)
            } catch {
                return try await requestManualAuthenticationForHost(host: host)
            }
        } else {
            return try await requestManualAuthenticationForHost(host: host)
        }
    }

    func onConnectToHost(host: RemoteHost) async throws {
        if let jumpServerURL = host.jumpServerUrl {
            guard
                let jumpHost = UserDefaults.standard.remoteHosts.first(where: {
                    $0.url == jumpServerURL
                })
            else {
                throw WorkSpaceStorage.FSError.MissingJumpingServer
            }
            let jumpCred = try await requestAuthenticationForHost(host: jumpHost)
            let cred = try await requestAuthenticationForHost(host: host)
            try await connectToHostWithCredentialsUsingJumpHost(
                host: host, jumpHost: jumpHost, hostCred: cred, jumpCred: jumpCred)
        } else {
            let cred = try await requestAuthenticationForHost(host: host)
            try await onConnectToHostWithCredentials(host: host, cred: cred)
        }
    }

    private func authenticationModeForHost(host: RemoteHost, cred: URLCredential) throws
        -> RemoteAuthenticationMode
    {
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
        return authenticationMode
    }

    private func connectionResultHandler(
        hostUrl: URL, error: (any Error)?, continuation: CheckedContinuation<Void, Error>
    ) {
        if let error {
            DispatchQueue.main.async {
                App.notificationManager.showErrorMessage(
                    error.localizedDescription)
            }
            continuation.resume(throwing: error)
        } else {
            DispatchQueue.main.async {
                App.loadRepository(url: hostUrl)
                App.notificationManager.showInformationMessage(
                    "remote.connected")
                // Set terminal service provider for the active terminal
                App.terminalManager.setTerminalServiceProviderForAll(
                    App.workSpaceStorage.terminalServiceProvider)
            }
            continuation.resume(returning: ())
        }
    }

    private func onRequestInteractiveKeyboard(prompt: String) async -> String {
        return
            (try? await authenticationRequestManager.requestPasswordAuthentication(
                title: "\(prompt)", usernameTitleKey: ""
            ).0) ?? ""
    }

    private func connectToHostWithCredentialsUsingJumpHost(
        host: RemoteHost,
        jumpHost: RemoteHost,
        hostCred: URLCredential,
        jumpCred: URLCredential
    ) async throws {
        guard let hostUrl = URL(string: host.url),
            let jumpServerUrlString = host.jumpServerUrl,
            let jumpHostUrl = URL(string: jumpServerUrlString)
        else {
            throw RemoteHostError.invalidUrl
        }

        let hostAuthenticationMode = try authenticationModeForHost(host: host, cred: hostCred)
        let jumpHostAuthenticationMode = try authenticationModeForHost(
            host: jumpHost, cred: jumpCred)

        try await App.notificationManager.withAsyncNotification(
            title: "remote.connecting",
            task: {
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, Error>) in
                    App.workSpaceStorage.connectToServer(
                        host: hostUrl, authenticationModeForHost: hostAuthenticationMode,
                        jumpServer: jumpHostUrl,
                        authenticationModeForJumpServer: jumpHostAuthenticationMode,
                        onRequestInteractiveKeyboard: onRequestInteractiveKeyboard
                    ) {
                        error in
                        connectionResultHandler(
                            hostUrl: hostUrl, error: error, continuation: continuation)
                    }
                }
            }
        )
    }

    func onConnectToHostWithCredentials(
        host: RemoteHost, cred: URLCredential
    ) async throws {

        if host.jumpServerUrl != nil {
            guard
                let jumpHost = UserDefaults.standard.remoteHosts.first(where: {
                    $0.url == host.jumpServerUrl
                })
            else {
                throw WorkSpaceStorage.FSError.MissingJumpingServer
            }
            let jumpHostCred = try await requestAuthenticationForHost(host: jumpHost)
            return try await connectToHostWithCredentialsUsingJumpHost(
                host: host, jumpHost: jumpHost, hostCred: cred, jumpCred: jumpHostCred)
        }

        guard let hostUrl = URL(string: host.url) else {
            throw RemoteHostError.invalidUrl
        }

        let authenticationMode = try authenticationModeForHost(host: host, cred: cred)

        try await App.notificationManager.withAsyncNotification(
            title: "remote.connecting",
            task: {
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, Error>) in
                    App.workSpaceStorage.connectToServer(
                        host: hostUrl, authenticationMode: authenticationMode,
                        onRequestInteractiveKeyboard: onRequestInteractiveKeyboard
                    ) {
                        error in
                        connectionResultHandler(
                            hostUrl: hostUrl, error: error, continuation: continuation)
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
                        onRenameHost: onRenameHost)
                    RemoteCreateSection(
                        hosts: hosts,
                        onConnectToHostWithCredentials: onConnectToHostWithCredentials,
                        onSaveHost: onSaveHost, onSaveCredentialsForHost: onSaveCredentialsForHost)
                }

            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .padding(.horizontal, 10)
            .scrollIndicators(.hidden)
        }
        .listStyle(.grouped)
        .onAppear {
            hosts = UserDefaults.standard.remoteHosts
        }
    }
}
