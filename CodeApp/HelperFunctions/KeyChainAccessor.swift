//
//  KeyChainAccessor.swift
//  Code
//
//  Created by Ken Chung on 14/4/2022.
//

import Foundation

class KeychainAccessor {

    static let shared = KeychainAccessor()

    public func hasCredentials(for url: URL) -> Bool {
        KeychainWrapper.standard.hasValue(forKey: "username;\(url.absoluteString)")
            && KeychainWrapper.standard.hasValue(forKey: "password;\(url.absoluteString)")
    }

    public func getCredentials(for url: URL) -> URLCredential? {
        guard
            let username = KeychainWrapper.standard.string(
                forKey: "username;\(url.absoluteString)"),
            let password = KeychainWrapper.standard.string(forKey: "password;\(url.absoluteString)")
        else {
            return nil
        }
        return URLCredential(user: username, password: password, persistence: .none)

    }

    public func storeCredentials(username: String, password: String, for url: URL) {
        KeychainWrapper.standard.set(
            username, forKey: "username;\(url.absoluteString)")
        KeychainWrapper.standard.set(
            password, forKey: "password;\(url.absoluteString)")
    }

    public func removeCredentials(for url: URL) -> Bool {
        KeychainWrapper.standard.removeObject(forKey: "username;\(url.absoluteString)")
            && KeychainWrapper.standard.removeObject(forKey: "password;\(url.absoluteString)")
    }

}
