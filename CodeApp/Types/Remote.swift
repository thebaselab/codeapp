//
//  RemoteType.swift
//  Code
//
//  Created by Ken Chung on 10/11/2022.
//

import Foundation

enum RemoteType: String, CaseIterable, Identifiable {
    case sftp
    case ftp
    case ftps
    var id: String { self.rawValue }
}

struct RemoteHost: Codable {
    var url: String
    var useKeyAuth: Bool  // Legacy flag for in-file id_rsa key authentication (.ssh/id_rsa)
    var displayName: String?
    var privateKeyContentKeychainID: String?
    var privateKeyPath: String?

    var rowDisplayName: String {
        displayName ?? URL(string: self.url)?.host ?? ""
    }
}

enum RemoteAuthenticationMode {
    case plainUsernamePassword(URLCredential)
    // File path of the ssh keys, default to Documents/.ssh
    case inFileSSHKey(URLCredential, URL?)
    case inMemorySSHKey(URLCredential, String)
}
