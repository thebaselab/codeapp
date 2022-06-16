//
//  NewRemote.swift
//  Code
//
//  Created by Ken Chung on 11/4/2022.
//

import SwiftUI

struct RemoteHost: Codable {
    var url: String
    var useKeyAuth: Bool
}

struct CreateRemoteSection: View {
    enum Field: Hashable {
        case address
        case port
        case username
        case password
    }

    @EnvironmentObject var App: MainApp

    @State var saveAddress: Bool = true
    @State var serverType: RemoteType.type = .sftp
    @State var address: String = ""
    @State var password: String = ""
    @State var privateKey: String = ""
    @State var privateKeyURL: String = ""
    @State var usesPrivateKey: Bool = false
    @State var showFileImporter: Bool = false
    @State var port: String = "22"
    @State var saveCredentials: Bool = false
    @State var username: String = ""
    @State var hasSSHKey = true

    @Binding var hosts: [RemoteHost]

    @FocusState var focusedField: Field?

    var body: some View {
        Section(header: Text("New remote")) {
            Group {
                HStack {
                    Image(systemName: "rectangle.connected.to.line.below")
                        .foregroundColor(.gray)
                        .font(.subheadline)

                    Picker("Protocol", selection: $serverType) {
                        ForEach(RemoteType.type.allCases, id: \.self) { type in
                            Text(type.rawValue.uppercased())
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
            .cornerRadius(15)

            if serverType == .sftp {
                Toggle("Use key authentication", isOn: $usesPrivateKey)
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

            if usesPrivateKey && hasSSHKey {
                SideBarButton("Show public key") {
                    let publicKeyUrl = getRootDirectory().appendingPathComponent(".ssh/id_rsa.pub")
                    App.openEditor(
                        urlString: publicKeyUrl.absoluteString, type: .file, inNewTab: true)
                }
            }

            if usesPrivateKey && !hasSSHKey {
                DescriptionText(
                    "SSH key not found in Documents/.ssh/id_rsa. Generate one by running ssh-keygen in the terminal."
                )

                SideBarButton("Reload key") {
                    let keyUrl = getRootDirectory().appendingPathComponent(".ssh/id_rsa")
                    hasSSHKey = FileManager.default.fileExists(atPath: keyUrl.path)
                }
            } else {
                SideBarButton("Connect") {

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

                    let cred = URLCredential(
                        user: username, password: password, persistence: .none)

                    App.workSpaceStorage.connectToServer(
                        host: url, credentials: cred, usesKey: usesPrivateKey
                    ) { error in
                        if let error = error {
                            App.notificationManager.showErrorMessage(error.localizedDescription)
                            return
                        } else {
                            DispatchQueue.main.async {
                                App.notificationManager.showInformationMessage(
                                    "Connected successfully.")
                            }
                            App.terminalInstance.terminalServiceProvider =
                                App.workSpaceStorage.terminalServiceProvider

                            guard saveAddress else {
                                return
                            }

                            let remoteHost = RemoteHost(
                                url: url.absoluteString, useKeyAuth: usesPrivateKey)
                            var remoteHosts = UserDefaults.standard.remoteHosts
                            remoteHosts = remoteHosts.filter { $0.url != url.absoluteString }
                            remoteHosts.append(remoteHost)

                            if UserDefaults.standard.remoteHosts.count > remoteHosts.count {
                                _ = KeychainAccessor.shared.removeCredentials(
                                    for: url.absoluteString)
                            }

                            UserDefaults.standard.remoteHosts = remoteHosts

                            DispatchQueue.main.async {
                                hosts = remoteHosts
                            }

                            guard saveCredentials else {
                                return
                            }

                            KeychainAccessor.shared.storeCredentials(
                                username: cred.user!, password: cred.password!,
                                for: url.absoluteString)

                        }
                    }
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
            let keyUrl = getRootDirectory().appendingPathComponent(".ssh/id_rsa")
            hasSSHKey = FileManager.default.fileExists(atPath: keyUrl.path)
        }
    }
}
