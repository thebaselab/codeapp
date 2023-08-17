//
//  LocalGitCredentialsHelper.swift
//  Code
//
//  Created by Ken Chung on 17/8/2023.
//

import SwiftGit2

struct LocalGitDomainSpecificCredentials: Codable {
    var matchingURL: String
    var credentials: LookupEntry

    enum LookupEntry: Codable {
        case https(usernameObjectID: String, passwordObjectID: String)
        case ssh(
            usernameObjectID: String, publicKeyObjectID: String, privateKeyObjectID: String,
            passphraseObjectID: String)
    }
}

extension LocalGitDomainSpecificCredentials {
    var _matchingURL: URL? {
        URL(string: self.matchingURL)
    }
}

final class LocalGitCredentialsHelper {
    // TODO: Localize this using LocalizedError
    enum HelperError: Error {
        case UnsupportedRemoteURL
        case UnableToAccessKeychain
        case UnableToLocateSuitableCredentials
    }

    enum SchemeType {
        case https, ssh

        init?(rawValue: String) {
            if rawValue == "https" {
                self = .https
            } else if rawValue == "ssh" {
                self = .ssh
            } else {
                return nil
            }
        }
    }

    private func accessLookupEntry(_ entry: LocalGitDomainSpecificCredentials.LookupEntry) throws
        -> Credentials
    {
        switch entry {
        case .https(let usernameID, let passwordID):
            guard let username = KeychainWrapper.standard.string(forKey: usernameID),
                let password = KeychainWrapper.standard.string(forKey: passwordID)
            else {
                throw HelperError.UnableToAccessKeychain
            }
            return Credentials.plaintext(username: username, password: password)
        case let .ssh(usernameObjectID, publicKeyObjectID, privateKeyObjectID, passphraseObjectID):
            guard let username = KeychainWrapper.standard.string(forKey: usernameObjectID),
                let publicKey = KeychainWrapper.standard.string(forKey: publicKeyObjectID),
                let privateKey = KeychainWrapper.standard.string(forKey: privateKeyObjectID),
                let passPhrase = KeychainWrapper.standard.string(forKey: passphraseObjectID)
            else {
                throw HelperError.UnableToAccessKeychain
            }
            return Credentials.sshMemory(
                username: username, publicKey: publicKey, privateKey: privateKey,
                passphrase: passPhrase)
        }
    }

    private func queryDomainSpecificCredentialsEntry(url: URL, schemeType: SchemeType)
        -> LocalGitDomainSpecificCredentials?
    {
        guard let queryHostname = url.host else { return nil }

        var candidates = UserDefaults.standard.gitCredentialsLookupEntries

        switch schemeType {
        case .https:
            candidates = candidates.filter {
                if case .https = $0.credentials {
                    return true
                } else {
                    return false
                }
            }
        case .ssh:
            candidates = candidates.filter {
                if case .ssh = $0.credentials {
                    return true
                } else {
                    return false
                }
            }
        }

        return candidates.first { candidate in
            guard let candidateURLHost = candidate._matchingURL?.host else {
                return false
            }
            return candidateURLHost == queryHostname
        }
    }

    func credentialsForRemote(remote: Remote) throws -> Credentials {
        guard let url = URL(string: remote.URL) else {
            throw HelperError.UnsupportedRemoteURL
        }
        return try credentialsForRemoteURL(url: url)
    }

    func credentialsForRemoteURL(url: URL) throws -> Credentials {
        guard let _scheme = url.scheme,
            let scheme = SchemeType(rawValue: _scheme)
        else {
            throw HelperError.UnsupportedRemoteURL
        }

        if let cred = queryDomainSpecificCredentialsEntry(url: url, schemeType: scheme) {
            return try accessLookupEntry(cred.credentials)
        }

        switch scheme {
        case .https:
            guard let username = KeychainWrapper.standard.string(forKey: "git-username"),
                let password = KeychainWrapper.standard.string(forKey: "git-password")
            else {
                throw HelperError.UnableToLocateSuitableCredentials
            }
            return Credentials.plaintext(username: username, password: password)
        case .ssh:
            // TODO: Global SSH Key
            throw HelperError.UnableToLocateSuitableCredentials
        }
    }

}
