//
//  ftpauth.swift
//  ftpauth
//
//  Created by Ken Chung on 11/8/2021.
//

import SwiftUI

struct RemoteAuthView: View {

    @State var username: String = ""
    @State var password: String = ""

    let host: RemoteHost
    var credCB: (String, String) -> Void

    var body: some View {
        Form {
            Section(
                header:
                    Text("Credentials for \(host.url)")
                    .foregroundColor(Color(id: "sideBarSectionHeader.foreground"))
            ) {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)

                SecureField(
                    (host.useKeyAuth || host.privateKeyContentKeychainID != nil
                        || host.privateKeyPath != nil) ? "Passphrase for private key" : "Password",
                    text: $password
                )
                .textContentType(.password)
                .disableAutocorrection(true)
                .autocapitalization(.none)

                Button("Connect") {
                    credCB(username, password)
                }
            }
        }
    }
}
