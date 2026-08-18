//
//  LocalGitCredentialsHelper.swift
//  Code
//
//  Created by Ken Chung on 17/8/2023.
//

import SwiftGit2

struct GitCredentials: Codable, Identifiable {
    var id: UUID = UUID()
    var hostname: String
    var credentials: LookupEntry

    enum LookupEntry: Codable {
        case https(usernameObjectID: String, passwordObjectID: String)
        case ssh(
            usernameObjectID: String, publicKeyObjectID: String, privateKeyObjectID: String,
            passphraseObjectID: String?)
    }
}

final class LocalGitCredentialsHelper {
    // TODO: Localize this using LocalizedError
    enum HelperError: Error {
        case UnsupportedRemoteURL
        case UnableToAccessKeychain
        case UnableToLocateSuitableCredentials
        case EmptyCredentials
        case CredentialsDoesNotExist
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

    static var credentials: [GitCredentials] {
        UserDefaults.standard.gitCredentialsLookupEntries
    }

    static func removeCredentials(credentialsID: UUID) throws {
        guard let credentialsToRemove = credentials.first(where: { $0.id == credentialsID }) else {
            throw HelperError.CredentialsDoesNotExist
        }
        switch credentialsToRemove.credentials {
        case let .https(usernameObjectID, passwordObjectID):
            KeychainAccessor.shared.removeObjectForKey(for: usernameObjectID)
            KeychainAccessor.shared.removeObjectForKey(for: passwordObjectID)
        case let .ssh(usernameObjectID, publicKeyObjectID, privateKeyObjectID, passphraseObjectID):
            KeychainAccessor.shared.removeObjectForKey(for: usernameObjectID)
            KeychainAccessor.shared.removeObjectForKey(for: publicKeyObjectID)
            KeychainAccessor.shared.removeObjectForKey(for: privateKeyObjectID)
            if let passphraseObjectID {
                KeychainAccessor.shared.removeObjectForKey(for: passphraseObjectID)
            }
        }
        UserDefaults.standard.gitCredentialsLookupEntries.removeAll { $0.id == credentialsID }
    }

    static func updateCredentials(
        hostname: String, username: String, password: String, for id: UUID
    ) throws {
        guard credentials.first(where: { $0.id == id }) != nil else {
            throw HelperError.CredentialsDoesNotExist
        }
        try removeCredentials(credentialsID: id)
        try addCredentials(hostname: hostname, username: username, password: password)
    }

    static func updateCredentials(
        hostname: String, username: String, publicKey: String, privateKey: String,
        passphrase: String?, for id: UUID
    ) throws {
        guard credentials.first(where: { $0.id == id }) != nil else {
            throw HelperError.CredentialsDoesNotExist
        }
        try removeCredentials(credentialsID: id)
        try addCredentials(
            hostname: hostname, username: username, publicKey: publicKey, privateKey: privateKey,
            passphrase: passphrase)
    }

    @discardableResult
    static func addCredentials(hostname: String, username: String, password: String) throws
        -> GitCredentials
    {
        guard !hostname.isEmpty, !username.isEmpty, !password.isEmpty else {
            throw HelperError.EmptyCredentials
        }
        let usernameObjectID = KeychainAccessor.shared.storeObject(value: username).uuidString
        let passwordObjectID = KeychainAccessor.shared.storeObject(value: password).uuidString

        let credentials = GitCredentials(
            hostname: hostname,
            credentials: .https(
                usernameObjectID: usernameObjectID, passwordObjectID: passwordObjectID)
        )
        UserDefaults.standard.gitCredentialsLookupEntries.append(credentials)
        return credentials
    }

    @discardableResult
    static func addCredentials(
        hostname: String, username: String, publicKey: String, privateKey: String,
        passphrase: String?
    ) throws -> GitCredentials {
        guard !hostname.isEmpty, !username.isEmpty, !publicKey.isEmpty, !privateKey.isEmpty else {
            throw HelperError.EmptyCredentials
        }
        let usernameObjectID = KeychainAccessor.shared.storeObject(value: username).uuidString
        let publicKeyObjectID = KeychainAccessor.shared.storeObject(value: publicKey).uuidString
        let privateKeyObjectID = KeychainAccessor.shared.storeObject(value: privateKey).uuidString
        let passphraseObjectID =
            passphrase == nil
            ? nil : KeychainAccessor.shared.storeObject(value: passphrase!).uuidString

        let credentials = GitCredentials(
            hostname: hostname,
            credentials: .ssh(
                usernameObjectID: usernameObjectID,
                publicKeyObjectID: publicKeyObjectID,
                privateKeyObjectID: privateKeyObjectID,
                passphraseObjectID: passphraseObjectID
            )
        )
        UserDefaults.standard.gitCredentialsLookupEntries.append(credentials)
        return credentials

    }

    private func accessLookupEntry(_ entry: GitCredentials.LookupEntry) throws
        -> Credentials
    {
        switch entry {
        case .https(let usernameID, let passwordID):
            guard let username = KeychainAccessor.shared.getObjectString(for: usernameID),
                let password = KeychainAccessor.shared.getObjectString(for: passwordID)
            else {
                throw HelperError.UnableToAccessKeychain
            }
            return Credentials.plaintext(username: username, password: password)
        case let .ssh(usernameObjectID, publicKeyObjectID, privateKeyObjectID, passphraseObjectID):
            guard let username = KeychainAccessor.shared.getObjectString(for: usernameObjectID),
                let publicKey = KeychainAccessor.shared.getObjectString(for: publicKeyObjectID),
                let privateKey = KeychainAccessor.shared.getObjectString(for: privateKeyObjectID)
            else {
                throw HelperError.UnableToAccessKeychain
            }
            if let passphraseObjectID {
                guard
                    let passPhrase = KeychainAccessor.shared.getObjectString(
                        for: passphraseObjectID)
                else {
                    throw HelperError.UnableToAccessKeychain
                }
                return Credentials.sshMemory(
                    username: username, publicKey: publicKey, privateKey: privateKey,
                    passphrase: passPhrase)
            } else {
                return Credentials.sshMemory(
                    username: username, publicKey: publicKey, privateKey: privateKey,
                    passphrase: "")
            }
        }
    }

    private func queryDomainSpecificCredentialsEntry(hostname: String, schemeType: SchemeType)
        -> GitCredentials?
    {
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
            return candidate.hostname == hostname
        }
    }

    func credentialsForRemote(remote: Remote) throws -> Credentials {
        let normalizedURL = LocalGitCredentialsHelper.normalizeRemoteURL(remote.URL)
        guard let url = URL(string: normalizedURL) else {
            throw HelperError.UnsupportedRemoteURL
        }
        return try credentialsForRemoteURL(url: url)
    }

    /// Normalizes a Git remote URL string to ensure proper parsing
    /// Handles bare IP:port and hostname:port formats by adding http:// scheme
    /// Preserves scp-like syntax (git@host:path) and fully-qualified URLs
    static func normalizeRemoteURL(_ urlString: String) -> String {
        // If URL already has a valid scheme and parses correctly, return as-is
        if let url = URL(string: urlString),
           let scheme = url.scheme,
           ["http", "https", "ssh", "git", "file", "ftp", "ftps"].contains(scheme),
           url.host != nil {
            return urlString
        }
        
        // Check if it's an scp-like URL (has @ but no ://)
        // e.g., git@github.com:user/repo.git
        if urlString.contains("@") && !urlString.contains("://") {
            return urlString  // Let parseRemoteURL handle it
        }
        
        // Check if it looks like bare IP:port or hostname:port
        // Pattern matches: 192.1.1.1:3000/path or forgejo.local:3000/path
        let pattern = #"^([a-zA-Z0-9\.\-]+):(\d+)(/.*)?$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)) != nil {
            // Prepend http:// as default scheme
            return "http://\(urlString)"
        }
        
        return urlString
    }

    static func parseRemoteURL(url: URL) -> URL? {
        if url.scheme == nil {
            // Handle scp-like syntax urls.
            // Reference: https://gitirc.eu/git-clone.html#URLS

            // From: [<user>@]<host>:/<path-to-git-repo> [<user>@]<host>:~<user>/<path-to-git-repo>
            // To: git://<host>[:<port>]/~<user>/<path-to-git-repo>
            guard
                let userAtHost = url.absoluteString.split(separator: ":").first,
                let pathToGitRepo = url.absoluteString.split(separator: "/", maxSplits: 1).last
            else {
                return nil
            }
            let user = url.absoluteString.dropFirst(userAtHost.count + 1).dropLast(
                pathToGitRepo.count + 1)

            if user.count > 0 {
                return URL(string: "ssh://\(userAtHost)/\(user)/\(pathToGitRepo)")
            } else {
                return URL(string: "ssh://\(userAtHost)/\(pathToGitRepo)")
            }
        }
        return url
    }

    func credentialsForRemoteURL(url: URL) throws -> Credentials {
        guard let url = LocalGitCredentialsHelper.parseRemoteURL(url: url),
            let hostname = url.host,
            let _scheme = url.scheme,
            let scheme = SchemeType(rawValue: _scheme)
        else {
            throw HelperError.UnsupportedRemoteURL
        }

        if let cred = queryDomainSpecificCredentialsEntry(hostname: hostname, schemeType: scheme) {
            return try accessLookupEntry(cred.credentials)
        }

        switch scheme {
        case .https:
            guard let username = KeychainAccessor.shared.getObjectString(for: "git-username"),
                let password = KeychainAccessor.shared.getObjectString(for: "git-password")
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
