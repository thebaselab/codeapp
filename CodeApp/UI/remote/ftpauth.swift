//
//  ftpauth.swift
//  ftpauth
//
//  Created by Ken Chung on 11/8/2021.
//

import SwiftUI

struct ftpAuthView: View {
    
    @State var username: String = ""
    @State var password: String = ""
    
    var credCB: (String, String) -> Void
    
    var body: some View {
        Form{
            Section(header: Text("FTP Authentication")){
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
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
