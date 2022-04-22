//
//  NewRemote.swift
//  Code
//
//  Created by Ken Chung on 11/4/2022.
//

import SwiftUI

struct CreateRemoteSection: View {
    enum Field: Hashable {
        case address
        case port
        case username
        case password
    }

    @EnvironmentObject var App: MainApp

    @State var saveAddress: Bool = true
    @State var serverType: RemoteType.type = .ftp
    @State var address: String = ""
    @State var password: String = ""
    @State var port: String = "21"
    @State var saveCredentials: Bool = false
    @State var username: String = ""
    @Binding var servers: [URL]

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
                            .focused($focusedField, equals: .address)
                            .autocapitalization(.none)
                    }

                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.gray)
                            .font(.subheadline)

                        TextField("Port", text: $port)
                            .focused($focusedField, equals: .port)
                    }

                    HStack {
                        Image(systemName: "person")
                            .foregroundColor(.gray)
                            .font(.subheadline)

                        TextField("Username", text: $username)
                            .focused($focusedField, equals: .username)
                            .autocapitalization(.none)
                    }

                    HStack {
                        Image(systemName: "key")
                            .foregroundColor(.gray)
                            .font(.subheadline)

                        SecureField("Password", text: $password)
                            .focused($focusedField, equals: .password)
                    }
                }
            }
            .padding(7)
            .background(Color.init(id: "input.background"))
            .cornerRadius(15)

            Toggle("Remember address", isOn: $saveAddress)

            if App.deviceSupportsBiometricAuth {
                Toggle("Remember credentials", isOn: $saveCredentials)
            }

            if saveCredentials {
                DescriptionText(
                    "Note: Credentials are stored inside the Secure Enclave in your device. We do not have access to it."
                )
            }

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

                guard !password.isEmpty else {
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

                App.workSpaceStorage.connectToServer(host: url, credentials: cred) { error in
                    if let error = error {
                        App.notificationManager.showErrorMessage(error.localizedDescription)
                        return
                    } else {
                        DispatchQueue.main.async {
                            App.notificationManager.showInformationMessage(
                                "Connected successfully.")
                        }

                        guard saveAddress else {
                            return
                        }

                        DispatchQueue.main.async {
                            if var hosts = UserDefaults.standard.stringArray(
                                forKey: "remote.hosts")
                            {
                                hosts.append(url.absoluteString)
                                servers = hosts.compactMap { URL(string: $0) }
                                UserDefaults.standard.set(hosts, forKey: "remote.hosts")
                            } else {
                                servers = [url]
                                UserDefaults.standard.set(
                                    [url.absoluteString], forKey: "remote.hosts")
                            }
                        }

                        guard saveCredentials else {
                            return
                        }

                        KeychainAccessor.shared.storeCredentials(
                            username: cred.user!, password: cred.password!, for: url)

                    }
                }

            }

        }.onChange(of: serverType) { value in
            if value == .sftp {
                port = "22"
            } else {
                port = "21"
            }
        }
        .onChange(of: saveAddress) { value in
            if !value {
                saveCredentials = false
            }
        }
    }
}
