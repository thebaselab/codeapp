//
//  SourceControlAuthenticationConfiguration.swift
//  Code App
//
//  Created by Ken Chung on 2/1/2021.
//

import SwiftUI

struct SourceControlAuthenticationConfiguration: View {

    @EnvironmentObject var App: MainApp

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
                Section(
                    header: Text("source_control.remote_credentials"),
                    footer: VStack(alignment: .leading) {

                        Text("credentials.note")
                            .padding(.bottom, 4)

                        Text("source_control.credentials.note")
                            .padding(.bottom, 4)

                        Button(action: {
                            isDocumentationPresented.toggle()
                        }) {
                            Text("source_control.setup_your_credentials")
                                .font(.footnote)
                        }
                    }

                ) {
                    TextField("User Name", text: $username)
                        .textContentType(.name)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                    SecureField("source_control.pat", text: $password)
                        .textContentType(.password)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)

                }
            }

        }.navigationBarTitle("Authentication", displayMode: .inline)
            .background(Color(.systemGroupedBackground))
            .navigationBarItems(
                trailing:
                    Button(NSLocalizedString("Done", comment: "")) {
                        self.presentationMode.wrappedValue.dismiss()
                    }
            )
            .onChange(of: username) { value in
                KeychainWrapper.standard.set(value, forKey: "git-username")
                App.workSpaceStorage.gitServiceProvider?.auth(name: value, password: password)
            }
            .onChange(of: password) { value in
                KeychainWrapper.standard.set(value, forKey: "git-password")
                App.workSpaceStorage.gitServiceProvider?.auth(name: username, password: value)
            }
            .sheet(isPresented: $isDocumentationPresented) {
                SafariView(
                    url: URL(
                        string:
                            "https://code.thebaselab.com/guides/version-control#set-up-your-credentials"
                    )!)

            }
    }
}
