//
//  NewRemote.swift
//  Code
//
//  Created by Ken Chung on 11/4/2022.
//

import SwiftUI

struct RemoteCreateSection: View {
    enum Field: Hashable {
        case address
        case port
        case username
        case password
        case privateKeyContent
    }

    let hosts: [RemoteHost]
    let onConnectToHostWithCredentials: (RemoteHost, URLCredential) async throws -> Void
    let onSaveHost: (RemoteHost) -> Void
    let onSaveCredentialsForHost: (RemoteHost, URLCredential) throws -> Void

    @EnvironmentObject var App: MainApp

    @State var saveAddress: Bool = true
    @State var serverType: RemoteType = .sftp
    @State var address: String = ""
    @State var password: String = ""
    @State var privateKeyContent: String = ""
    @State var usesPrivateKey: Bool = false
    @State var showFileImporter: Bool = false
    @State var port: String = "22"
    @State var saveCredentials: Bool = true
    @State var username: String = ""
    @State var hasSSHKey = true
    @State var usesJumpServer = false
    @State var jumpServerUrl: String? = nil

    @FocusState var focusedField: Field?

    var hostsSuitableForJumphost: [RemoteHost] {
        hosts.filter { $0.url.hasPrefix("sftp") && $0.jumpServerUrl == nil }
    }

    func resetAllFields() {
        saveAddress = true
        serverType = .sftp
        address = ""
        password = ""
        privateKeyContent = ""
        usesPrivateKey = false
        showFileImporter = false
        port = "22"
        saveCredentials = false
        username = ""
        hasSSHKey = true
    }

    func connect() {
        guard !address.isEmpty else {
            App.notificationManager.showErrorMessage("Address cannot be empty.")
            focusedField = .address
            return
        }

        guard !username.isEmpty else {
            App.notificationManager.showErrorMessage("Username cannot be empty.")
            focusedField = .username
            return
        }

        guard !password.isEmpty || usesPrivateKey else {
            App.notificationManager.showErrorMessage("Password cannot be empty.")
            focusedField = .password
            return
        }

        guard
            let url = URL(
                string: serverType.rawValue.lowercased() + "://" + address + ":\(port)")
        else {
            App.notificationManager.showErrorMessage("Invalid address.")
            focusedField = .address
            return
        }

        let privateKeyContentKeyChainId = UUID().uuidString
        let cred = URLCredential(
            user: username, password: password, persistence: .none)
        let remoteHost = RemoteHost(
            url: url.absoluteString,
            useKeyAuth: false,
            privateKeyContentKeychainID: usesPrivateKey ? privateKeyContentKeyChainId : nil,
            jumpServerUrl: usesJumpServer ? jumpServerUrl : nil
        )

        if usesPrivateKey {
            KeychainAccessor.shared.storeObject(
                for: privateKeyContentKeyChainId, value: privateKeyContent)
        }

        Task {
            do {
                try await onConnectToHostWithCredentials(remoteHost, cred)
                if saveAddress {
                    onSaveHost(remoteHost)
                }
                if saveAddress && saveCredentials {
                    try onSaveCredentialsForHost(remoteHost, cred)
                }
                resetAllFields()
            } catch {
                KeychainAccessor.shared.removeObjectForKey(for: privateKeyContentKeyChainId)
            }
        }
    }

    var body: some View {
        Section(
            header:
                Text("New remote")
                .foregroundColor(Color(id: "sideBarSectionHeader.foreground"))
        ) {
            Group {
                HStack {
                    Image(systemName: "rectangle.connected.to.line.below")
                        .foregroundColor(.gray)
                        .font(.subheadline)

                    Picker("Protocol", selection: $serverType) {
                        ForEach(RemoteType.allCases, id: \.self) { type in
                            if type == .sftp {
                                Text("SSH")
                            } else {
                                Text(type.rawValue.uppercased())
                            }
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    Spacer()
                }.frame(maxHeight: 20)

                Group {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.gray)
                            .font(.subheadline)

                        TextField("Address", text: $address)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.URL)
                            .focused($focusedField, equals: .address)
                    }

                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.gray)
                            .font(.subheadline)

                        TextField("Port", text: $port)
                            .focused($focusedField, equals: .port)
                            .keyboardType(.numberPad)
                    }

                    HStack {
                        Image(systemName: "person")
                            .foregroundColor(.gray)
                            .font(.subheadline)

                        TextField("Username", text: $username)
                            .focused($focusedField, equals: .username)
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                    }

                    if usesPrivateKey {
                        HStack {
                            Image(systemName: "key")
                                .foregroundColor(.gray)
                                .font(.subheadline)

                            TextEditorWithPlaceholder(
                                placeholder:
                                    "remote.private_key_content",
                                text: $privateKeyContent,
                                customFont: .custom("Menlo", size: 13, relativeTo: .footnote)
                            )
                            .focused($focusedField, equals: .privateKeyContent)
                            .disableAutocorrection(true)
                            .autocapitalization(.none)

                        }.frame(height: 300)

                        Button(action: {
                            showFileImporter.toggle()
                        }) {
                            Text("remote.import_from_file")
                                .font(.footnote)
                                .foregroundColor(.blue)
                        }
                        .fileImporter(
                            isPresented: $showFileImporter, allowedContentTypes: [.data]
                        ) { result in
                            guard let url = try? result.get(),
                                url.startAccessingSecurityScopedResource(),
                                let keyFileContent = try? String(contentsOfFile: url.path)
                            else {
                                App.notificationManager.showErrorMessage(
                                    "errors.failed_to_import_key")
                                return
                            }
                            url.stopAccessingSecurityScopedResource()
                            privateKeyContent = keyFileContent
                        }
                        .frame(maxWidth: .infinity)
                    }

                    HStack {
                        Image(systemName: "key")
                            .foregroundColor(.gray)
                            .font(.subheadline)

                        SecureField(
                            usesPrivateKey ? "Key passphrase" : "Password",
                            text: $password
                        )
                        .focused($focusedField, equals: .password)
                    }

                }
            }
            .padding(7)
            .background(Color.init(id: "input.background"))
            .cornerRadius(10)

            if usesPrivateKey {
                DescriptionText(
                    "remote.setup_note"
                )
            }

            Button(action: {
                App.safariManager.showSafari(
                    url: URL(
                        string:
                            "https://code.thebaselab.com/guides/connecting-to-a-remote-server-ssh-ftp#set-up-your-remote-server"
                    )!)
            }) {
                Text("remote.setup_remote_server")
                    .font(.footnote)
                    .foregroundColor(.blue)
            }

            if serverType == .sftp {
                Toggle("Use Key Authentication", isOn: $usesPrivateKey)
                Toggle("remote.use_jump_server", isOn: $usesJumpServer)
                    .disabled(jumpServerUrl == nil)
            }

            if usesJumpServer {
                HStack {
                    Image(systemName: "rectangle.connected.to.line.below")
                        .foregroundColor(.gray)
                        .font(.subheadline)

                    Picker("remote.jump_using", selection: $jumpServerUrl) {
                        ForEach(hostsSuitableForJumphost, id: \.url) { host in
                            Text(host.rowDisplayName)
                                .tag(host.url as String?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    Spacer()
                }.frame(maxHeight: 20)
            }

            Toggle("Remember address", isOn: $saveAddress)

            if App.deviceSupportsBiometricAuth {
                Toggle("Remember credentials", isOn: $saveCredentials)
            }

            if saveCredentials {
                DescriptionText(
                    "credentials.note"
                )
            }

            SideBarButton("Connect") {
                if usesPrivateKey && privateKeyContent.isEmpty {
                    focusedField = .privateKeyContent
                } else {
                    connect()
                }
            }

        }.onChange(of: serverType) { value in
            if value == .sftp {
                port = "22"
            } else {
                usesPrivateKey = false
                port = "21"
            }
        }
        .onChange(of: saveAddress) { value in
            if !value {
                saveCredentials = false
            }
        }
        .onAppear {
            jumpServerUrl = hostsSuitableForJumphost.first?.url
        }
    }
}
