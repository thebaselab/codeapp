//
//  SourceControlAuthenticationConfiguration.swift
//  Code App
//
//  Created by Ken Chung on 2/1/2021.
//

import LocalAuthentication
import SwiftUI

func withDeviceOwnerAuthentication(titleKey: String, action: () async -> Void) async throws {
    let title = NSLocalizedString(titleKey, comment: "")
    let context = LAContext()
    let authSuccess = try await context.evaluatePolicy(
        .deviceOwnerAuthentication, localizedReason: title)
    guard authSuccess else {
        throw NSError(descriptionKey: "Biometric authentication failed")
    }
    await action()
}

private struct DeviceOwnerProtectedField<Content: View>: View {

    var authenticationTitleKey: String
    @Binding var locked: Bool
    @ViewBuilder let content: Content

    var body: some View {
        if !locked {
            content
        } else {
            HStack {
                Text("********")
                Spacer()
                Image(systemName: "eye")
            }
            .contentShape(Rectangle())
            .foregroundColor(.secondary)
            .onTapGesture {
                Task {
                    try await withDeviceOwnerAuthentication(
                        titleKey: authenticationTitleKey
                    ) {
                        withAnimation {
                            locked = false
                        }
                    }
                }
            }
        }

    }
}

private struct PasswordBasedAuthenticationSection: View {

    @Binding var username: String
    @Binding var password: String

    var body: some View {
        Section(
            header: Text("source_control.password_based_authentication")
        ) {
            TextField("source_control.username", text: $username)
                .textContentType(.username)
                .disableAutocorrection(true)
                .autocapitalization(.none)
            SecureField("source_control.pat_or_password", text: $password)
                .textContentType(.password)
                .disableAutocorrection(true)
                .autocapitalization(.none)
        }

    }
}

private struct KeyBasedAuthenticationSections: View {
    @EnvironmentObject var App: MainApp

    @Binding var username: String
    @Binding var publicKey: String
    @Binding var privateKey: String
    @Binding var passphrase: String

    @State var showImportPublicKeySheet = false
    @State var showImportPrivateKeySheet = false
    @State var publicKeyLocked: Bool
    @State var privateKeyLocked: Bool

    init(
        username: Binding<String>, publicKey: Binding<String>, privateKey: Binding<String>,
        passphrase: Binding<String>, deviceOwnerProtected: Bool
    ) {
        self._username = username
        self._publicKey = publicKey
        self._privateKey = privateKey
        self._passphrase = passphrase
        if deviceOwnerProtected {
            _publicKeyLocked = State(initialValue: true)
            _privateKeyLocked = State(initialValue: true)
        } else {
            _publicKeyLocked = State(initialValue: false)
            _privateKeyLocked = State(initialValue: false)
        }
    }

    func handleFileImportResult(_ result: Result<URL, Error>) -> String? {
        guard let url = try? result.get(),
            url.startAccessingSecurityScopedResource(),
            let keyFileContent = try? String(contentsOfFile: url.path)
        else {
            App.notificationManager.showErrorMessage(
                "errors.failed_to_import_key")
            return nil
        }
        return keyFileContent
    }

    var body: some View {
        Group {
            /*
            Section("source_control.username") {
                TextField("source_control.username", text: $username)
                    .textContentType(.username)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
            }
             */

            Section("source_control.public_key") {
                DeviceOwnerProtectedField(
                    authenticationTitleKey: "source_control.editing_public_key",
                    locked: $publicKeyLocked
                ) {
                    TextEditorWithPlaceholder(
                        placeholder:
                            "source_control.key_content",
                        text: $publicKey,
                        customFont: .custom("Menlo", size: 13, relativeTo: .footnote)
                    )
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .frame(minHeight: 80)
                }
                Button("common.import") {
                    showImportPublicKeySheet.toggle()
                }
            }
            .fileImporter(
                isPresented: $showImportPublicKeySheet, allowedContentTypes: [.data]
            ) { result in
                if let publicKey = handleFileImportResult(result) {
                    self.publicKey = publicKey
                }
            }

            Section("source_control.private_key") {
                DeviceOwnerProtectedField(
                    authenticationTitleKey: "source_control.editing_ssh_private_key",
                    locked: $privateKeyLocked
                ) {
                    TextEditorWithPlaceholder(
                        placeholder:
                            "source_control.key_content",
                        text: $privateKey,
                        customFont: .custom("Menlo", size: 13, relativeTo: .footnote)
                    )
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .frame(minHeight: 80)
                }

                Button("common.import") {
                    showImportPrivateKeySheet.toggle()
                }

                SecureField("source_control.passphrase_optional", text: $passphrase)
                    .textContentType(.password)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
            }
            .fileImporter(
                isPresented: $showImportPrivateKeySheet, allowedContentTypes: [.data]
            ) { result in
                if let privateKey = handleFileImportResult(result) {
                    self.privateKey = privateKey
                }
            }

        }

    }
}

private struct HostnameSection: View {

    @Binding var hostname: String

    var body: some View {
        Section("source_control.hostname") {
            TextField("example.com", text: $hostname)
                .textContentType(.URL)
                .disableAutocorrection(true)
                .autocapitalization(.none)
        }
    }
}

private struct UpdateKeyBasedCredentialsView: View {
    var credentials: GitCredentials
    var onUpdateCredentials: (String, String, String, String, String?, UUID) -> Void

    @State var hostname: String
    @State var username: String
    @State var publicKey: String
    @State var privateKey: String
    @State var passphrase: String

    var originalHash: Int? = nil

    var hash: Int {
        var hasher = Hasher()
        hasher.combine(hostname)
        hasher.combine(username)
        hasher.combine(publicKey)
        hasher.combine(privateKey)
        hasher.combine(passphrase)
        return hasher.finalize()
    }

    init(
        credentials: GitCredentials,
        onUpdateCredentials: @escaping (String, String, String, String, String?, UUID) -> Void
    ) {
        guard
            case let .ssh(
                usernameObjectID, publicKeyObjectID, privateKeyObjectID, passphraseObjectID) =
                credentials.credentials
        else {
            fatalError("UpdateKeyBasedCredentialsView must be used with ssh credentials")
        }
        self.credentials = credentials
        self.onUpdateCredentials = onUpdateCredentials
        self._hostname = State(initialValue: credentials.hostname)
        self._username = State(
            initialValue: KeychainAccessor.shared.getObjectString(for: usernameObjectID) ?? "")
        self._publicKey = State(
            initialValue: KeychainAccessor.shared.getObjectString(for: publicKeyObjectID) ?? "")
        self._privateKey = State(
            initialValue: KeychainAccessor.shared.getObjectString(for: privateKeyObjectID) ?? "")
        if let passphraseObjectID {
            self._passphrase = State(
                initialValue: KeychainAccessor.shared.getObjectString(for: passphraseObjectID) ?? ""
            )
        } else {
            self._passphrase = State(initialValue: "")
        }

    }

    var body: some View {
        Form {
            Section("source_control.hostname") {
                Text(hostname)
                    .foregroundColor(.secondary)
            }

            KeyBasedAuthenticationSections(
                username: $username, publicKey: $publicKey, privateKey: $privateKey,
                passphrase: $passphrase, deviceOwnerProtected: true)

        }
        .navigationBarTitle("source_control.credentials", displayMode: .inline)
        .onDisappear {
            if hash != originalHash {
                if passphrase.isEmpty {
                    onUpdateCredentials(
                        hostname, username, publicKey, privateKey, nil, credentials.id)
                } else {
                    onUpdateCredentials(
                        hostname, username, publicKey, privateKey, passphrase, credentials.id)
                }
            }
        }
    }

}

private struct UpdatePasswordCredentialsView: View {
    var credentials: GitCredentials
    var onUpdateCredentials: (String, String, String, UUID) -> Void

    @State var username: String
    @State var password: String
    @State var hostname: String
    var originalHash: Int? = nil

    var hash: Int {
        var hasher = Hasher()
        hasher.combine(username)
        hasher.combine(password)
        hasher.combine(hostname)
        return hasher.finalize()
    }

    init(
        credentials: GitCredentials,
        onUpdateCredentials: @escaping (String, String, String, UUID) -> Void
    ) {
        guard case let .https(usernameObjectID, passwordObjectID) = credentials.credentials else {
            fatalError("UpdatePasswordCredentialsView must be used with https credentials")
        }
        self.credentials = credentials
        self.onUpdateCredentials = onUpdateCredentials
        self._username = State(
            initialValue: KeychainAccessor.shared.getObjectString(for: usernameObjectID) ?? "")
        self._password = State(
            initialValue: KeychainAccessor.shared.getObjectString(for: passwordObjectID) ?? "")
        self._hostname = State(initialValue: credentials.hostname)
        self.originalHash = hash
    }

    var body: some View {
        Form {
            Section("source_control.hostname") {
                Text(hostname)
                    .foregroundColor(.secondary)
            }

            PasswordBasedAuthenticationSection(username: $username, password: $password)
        }
        .navigationBarTitle("source_control.credentials", displayMode: .inline)
        .onDisappear {
            if hash != originalHash {
                onUpdateCredentials(hostname, username, password, credentials.id)
            }
        }
    }
}

private struct CreateKeyBasedCredentialsView: View {
    var onCreateCredentials: (String, String, String, String, String?) -> Void

    @Environment(\.dismiss) var dismiss

    @State var hostname: String = ""
    @State var username: String = "git"
    @State var publicKey: String = ""
    @State var privateKey: String = ""
    @State var passphrase: String = ""

    var body: some View {
        Form {
            HostnameSection(hostname: $hostname)
            KeyBasedAuthenticationSections(
                username: $username, publicKey: $publicKey, privateKey: $privateKey,
                passphrase: $passphrase, deviceOwnerProtected: false)
        }
        .navigationBarTitle("source_control.new_credentials", displayMode: .inline)
        .navigationBarItems(
            trailing:
                Button("common.add") {
                    onCreateCredentials(
                        hostname, username, publicKey, privateKey,
                        passphrase.isEmpty ? nil : passphrase)
                    dismiss()
                }
                .disabled(
                    hostname.isEmpty || username.isEmpty || publicKey.isEmpty || privateKey.isEmpty)
        )
    }
}

private struct CreatePasswordCredentialsView: View {
    var onCreateCredentials: (String, String, String) -> Void

    @Environment(\.dismiss) var dismiss

    @State var hostname: String = ""
    @State var username: String = ""
    @State var password: String = ""

    var body: some View {
        Form {
            HostnameSection(hostname: $hostname)

            PasswordBasedAuthenticationSection(username: $username, password: $password)
        }
        .navigationBarTitle("source_control.new_credentials", displayMode: .inline)
        .navigationBarItems(
            trailing:
                Button("common.add") {
                    onCreateCredentials(hostname, username, password)
                    dismiss()
                }
                .disabled(username.isEmpty || password.isEmpty || hostname.isEmpty)
        )

    }
}

private struct CredentialsView: View {

    var credentials: GitCredentials
    var onUpdatePasswordBasedCredentials: (String, String, String, UUID) -> Void
    var onUpdateKeyBasedCredentials: (String, String, String, String, String?, UUID) -> Void

    var body: some View {
        switch credentials.credentials {
        case .https:
            UpdatePasswordCredentialsView(
                credentials: credentials,
                onUpdateCredentials: onUpdatePasswordBasedCredentials
            )
        case .ssh:
            UpdateKeyBasedCredentialsView(
                credentials: credentials, onUpdateCredentials: onUpdateKeyBasedCredentials)
        }
    }
}

private struct URLSpecificCredentialsSections: View {

    @EnvironmentObject var App: MainApp
    @State var entries: [GitCredentials] = []

    func onCreatePasswordBasedCredentials(hostname: String, username: String, password: String) {
        do {
            try LocalGitCredentialsHelper.addCredentials(
                hostname: hostname, username: username, password: password)
            entries = LocalGitCredentialsHelper.credentials
        } catch {
            App.notificationManager.showErrorMessage(error.localizedDescription)
        }
    }

    func onUpdatePasswordBasedCredentials(
        hostname: String, username: String, password: String, for id: UUID
    ) {
        do {
            try LocalGitCredentialsHelper.updateCredentials(
                hostname: hostname, username: username, password: password, for: id)
            entries = LocalGitCredentialsHelper.credentials
        } catch {
            App.notificationManager.showErrorMessage(error.localizedDescription)
        }
    }

    func onCreateKeyBasedCredentials(
        hostname: String, username: String, publicKey: String, privateKey: String,
        passphrase: String?
    ) {
        do {
            try LocalGitCredentialsHelper.addCredentials(
                hostname: hostname, username: username, publicKey: publicKey,
                privateKey: privateKey, passphrase: passphrase)
            entries = LocalGitCredentialsHelper.credentials
        } catch {
            App.notificationManager.showErrorMessage(error.localizedDescription)
        }
    }

    func onUpdateKeyBasedCredentials(
        hostname: String, username: String, publicKey: String, privateKey: String,
        passphrase: String?, for id: UUID
    ) {
        do {
            try LocalGitCredentialsHelper.updateCredentials(
                hostname: hostname, username: username, publicKey: publicKey,
                privateKey: privateKey, passphrase: passphrase, for: id)
            entries = LocalGitCredentialsHelper.credentials
        } catch {
            App.notificationManager.showErrorMessage(error.localizedDescription)
        }
    }

    func removeRows(at offsets: IndexSet) {
        do {
            try offsets.forEach {
                try LocalGitCredentialsHelper.removeCredentials(credentialsID: entries[$0].id)
            }
            entries = LocalGitCredentialsHelper.credentials
        } catch {
            App.notificationManager.showErrorMessage(error.localizedDescription)
        }
    }

    var body: some View {
        Group {
            if !entries.isEmpty {
                Section(
                    header: Text("source_control.hostname_based_credentials")
                ) {
                    ForEach(entries) { entry in
                        NavigationLink(entry.hostname) {
                            CredentialsView(
                                credentials: entry,
                                onUpdatePasswordBasedCredentials: onUpdatePasswordBasedCredentials,
                                onUpdateKeyBasedCredentials: onUpdateKeyBasedCredentials
                            )
                        }
                    }.onDelete(perform: removeRows)

                }
            }

            Section(footer: Text("credentials.note")) {
                NavigationLink("source_control.add_password_based_credentials") {
                    CreatePasswordCredentialsView(
                        onCreateCredentials: onCreatePasswordBasedCredentials
                    )
                }

                NavigationLink("source_control.add_key_based_credentials") {
                    CreateKeyBasedCredentialsView(onCreateCredentials: onCreateKeyBasedCredentials)
                }
            }
            .onAppear {
                entries = LocalGitCredentialsHelper.credentials
            }
        }
    }
}

struct SourceControlAuthenticationConfiguration: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var alertManager: AlertManager

    @State var username: String
    @State var password: String
    @State var isDocumentationPresented: Bool = false

    @Environment(\.presentationMode) var presentationMode

    init() {
        if let usr_name = KeychainWrapper.standard.string(forKey: "git-username") {
            _username = State(initialValue: usr_name)
        } else {
            _username = State(initialValue: "")
        }
        if let usr_pwd = KeychainWrapper.standard.string(forKey: "git-password") {
            _password = State(initialValue: usr_pwd)
        } else {
            _password = State(initialValue: "")
        }
    }

    var body: some View {
        VStack {
            Form {
                Group {
                    PasswordBasedAuthenticationSection(username: $username, password: $password)
                    URLSpecificCredentialsSections()
                }.listRowBackground(Color.init(id: "list.inactiveSelectionBackground"))
            }

        }.navigationBarTitle("source_control.git_authentication", displayMode: .inline)
            .navigationBarItems(
                trailing:
                    HStack {
                        Button(action: {
                            isDocumentationPresented.toggle()
                        }) {
                            Image(systemName: "questionmark.circle")
                        }
                        Button("common.done") {
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    }
            )
            .sheet(isPresented: $isDocumentationPresented) {
                SafariView(
                    url: URL(
                        string:
                            "https://code.thebaselab.com/guides/version-control#set-up-your-credentials"
                    )!)
            }
            .onDisappear {
                if !username.isEmpty {
                    KeychainWrapper.standard.set(username, forKey: "git-username")
                } else {
                    KeychainWrapper.standard.removeObject(forKey: "git-username")
                }
                if !password.isEmpty {
                    KeychainWrapper.standard.set(password, forKey: "git-password")
                } else {
                    KeychainWrapper.standard.removeObject(forKey: "git-password")
                }
            }
            .background(Color(id: "sideBar.background"))
    }
}
