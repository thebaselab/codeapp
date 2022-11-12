//
//  SourceControlIdentityConfiguration.swift
//  Code App
//
//  Created by Ken Chung on 14/12/2020.
//

import SwiftUI

struct SourceControlIdentityConfiguration: View {

    @EnvironmentObject var App: MainApp

    @AppStorage("user_name") var username: String = ""
    @AppStorage("user_email") var email: String = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("Author Identity", comment: ""))) {
                TextField("Name", text: $username)
                    .textContentType(.name)
                    .disableAutocorrection(true)

                TextField("Email address", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
            }
        }.navigationBarTitle("Author Identity", displayMode: .inline)
            .background(Color(.systemGroupedBackground))
            .navigationBarItems(
                trailing:
                    Button(NSLocalizedString("Done", comment: "")) {
                        self.presentationMode.wrappedValue.dismiss()
                    }
            )
            .onChange(of: username) { value in
                App.workSpaceStorage.gitServiceProvider?.sign(name: value, email: email)
            }
            .onChange(of: email) { value in
                App.workSpaceStorage.gitServiceProvider?.sign(name: username, email: value)
            }
    }
}
