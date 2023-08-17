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

struct SourceControlAuthenticationConfiguration: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var alertManager: AlertManager

    @State var username: String
    @State var password: String
    @State var isDocumentationPresented: Bool = false
    @State var sshKey: String
    @State var isEditingSSHKey: Bool = false
    @State var isSSHKeyConfigured: Bool
    @State var isConfirmingSSHKeyReset: Bool = false

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
        if let sshKey = KeychainWrapper.standard.string(forKey: "git-ssh-key") {
            _sshKey = State(initialValue: sshKey)
            _isSSHKeyConfigured = State(initialValue: true)
        } else {
            _sshKey = State(initialValue: "")
            _isSSHKeyConfigured = State(initialValue: false)
        }
    }

    func resetSSHKey() {
        sshKey = ""
        isSSHKeyConfigured = false
        KeychainWrapper.standard.removeObject(forKey: "git-ssh-key")
    }

    var body: some View {
        VStack {
            Form {
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

                Section("source_control.ssh_authentication") {
                    if !isSSHKeyConfigured || isEditingSSHKey {
                        TextEditorWithPlaceholder(
                            placeholder:
                                "source_control.private_key_content",
                            text: $sshKey,
                            customFont: .custom("Menlo", size: 13, relativeTo: .footnote)
                        )
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
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
                                    titleKey: "source_control.editing_ssh_private_key"
                                ) {
                                    withAnimation {
                                        isEditingSSHKey = true
                                    }
                                }
                            }
                        }
                    }

                    if isSSHKeyConfigured && !isEditingSSHKey {
                        Button("common.reset", role: .destructive) {
                            isConfirmingSSHKeyReset.toggle()
                        }
                        .confirmationDialog(
                            "source_control.ssh_key_reset_confirmation",
                            isPresented: $isConfirmingSSHKeyReset
                        ) {
                            Button("common.reset", role: .destructive) {
                                resetSSHKey()
                            }
                            Button("common.cancel", role: .cancel) {
                                isConfirmingSSHKeyReset = false
                            }
                        }
                    }
                }

                Section(
                    header: Text("source_control.url_specific_credentials"),
                    footer: Text("credentials.note")
                ) {
                    Button("source_control.add_new_credentials") {

                    }
                }
            }

        }.navigationBarTitle("source_control.git_authentication", displayMode: .inline)
            .background(Color(.systemGroupedBackground))
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
                if !sshKey.isEmpty {
                    KeychainWrapper.standard.set(sshKey, forKey: "git-ssh-key")
                } else {
                    KeychainWrapper.standard.removeObject(forKey: "git-ssh-key")
                }
            }
    }
}
