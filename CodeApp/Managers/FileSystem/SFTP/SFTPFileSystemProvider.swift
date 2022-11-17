//
//  SFTPFileSystemProvider.swift
//  Code
//
//  Created by Ken Chung on 13/4/2022.
//

import Foundation
import NMSSH

class SFTPFileSystemProvider: NSObject, FileSystemProvider {

    static var registeredScheme: String = "sftp"
    var gitServiceProvider: GitServiceProvider? = nil
    var searchServiceProvider: SearchServiceProvider? = nil
    var terminalServiceProvider: TerminalServiceProvider? {
        _terminalServiceProvider
    }
    var _terminalServiceProvider: SFTPTerminalServiceProvider? = nil

    var homePath: String? = ""
    var fingerPrint: String? = nil

    private var didDisconnect: (Error) -> Void
    private var session: NMSSHSession
    private let queue = DispatchQueue(label: "sftp.serial.queue")

    init?(
        baseURL: URL, cred: URLCredential, didDisconnect: @escaping (Error) -> Void,
        onTerminalData: ((Data) -> Void)?
    ) {
        guard baseURL.scheme == "sftp",
            let host = baseURL.host,
            let port = baseURL.port,
            let username = cred.user
        else {
            return nil
        }
        self.didDisconnect = didDisconnect
        session = NMSSHSession(host: host, port: port, andUsername: username)
        super.init()

        session.delegate = self
        self._terminalServiceProvider = SFTPTerminalServiceProvider(
            baseURL: baseURL, cred: cred)
        if let onTerminalData = onTerminalData {
            self._terminalServiceProvider?.onStderr(callback: onTerminalData)
            self._terminalServiceProvider?.onStdout(callback: onTerminalData)
        }

    }

    deinit {
        self._terminalServiceProvider?.disconnect()
        self.session.sftp.disconnect()
        self.session.disconnect()
    }

    func connect(password: String, usesKey: Bool, completionHandler: @escaping (Error?) -> Void) {

        self._terminalServiceProvider?.connect(
            password: password, usesKey: usesKey,
            completionHandler: { _ in
                return
            })

        queue.async {
            self.session.connect()

            if self.session.isConnected {
                if usesKey {
                    let privateKeyUrl = getRootDirectory().appendingPathComponent(".ssh/id_rsa")
                    if let privateKeyContent = try? String(contentsOf: privateKeyUrl) {
                        self.session.authenticateBy(
                            inMemoryPublicKey: nil, privateKey: privateKeyContent,
                            andPassword: password.isEmpty ? nil : password)
                    }
                } else {
                    self.session.authenticate(byPassword: password)
                }

            }

            guard self.session.isConnected && self.session.isAuthorized else {
                completionHandler(WorkSpaceStorage.FSError.AuthFailure)
                return
            }

            self.session.sftp.connect()
            self.fingerPrint = self.session.fingerprint(self.session.fingerprintHash)

            completionHandler(nil)
        }

    }

    func contentsOfDirectory(at url: URL, completionHandler: @escaping ([URL]?, Error?) -> Void) {
        queue.async {
            let files = self.session.sftp.contentsOfDirectory(atPath: url.path)
            guard let files = files else {
                completionHandler(nil, WorkSpaceStorage.FSError.Unknown)
                return
            }
            completionHandler(files.map { url.appendingPathComponent($0.filename) }, nil)
        }
    }

    func fileExists(at url: URL, completionHandler: @escaping (Bool) -> Void) {
        queue.async {
            completionHandler(self.session.sftp.fileExists(atPath: url.path))
        }
    }

    func createDirectory(
        at: URL, withIntermediateDirectories: Bool, completionHandler: @escaping (Error?) -> Void
    ) {
        queue.async {
            let success = self.session.sftp.createDirectory(atPath: at.path)
            if success {
                completionHandler(nil)
            } else {
                completionHandler(WorkSpaceStorage.FSError.Unknown)
            }
        }
    }

    func copyItem(at: URL, to: URL, completionHandler: @escaping (Error?) -> Void) {

        if to.isFileURL {
            copyItemFromRemoteToLocal(at: at, to: to, completionHandler: completionHandler)
            return
        }

        queue.async {
            let success = self.session.sftp.copyContents(ofPath: at.path, toFileAtPath: to.path)
            if success {
                completionHandler(nil)
            } else {
                completionHandler(WorkSpaceStorage.FSError.Unknown)
            }
        }
    }

    private func copyItemFromRemoteToLocal(
        at: URL, to: URL, completionHandler: @escaping (Error?) -> Void
    ) {
        queue.async {
            let data = self.session.sftp.contents(atPath: at.path)

            guard let data = data else {
                completionHandler(WorkSpaceStorage.FSError.Unknown)
                return
            }

            do {
                try data.write(to: to)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    func moveItem(at: URL, to: URL, completionHandler: @escaping (Error?) -> Void) {
        queue.async {
            let success = self.session.sftp.moveItem(atPath: at.path, toPath: to.path)
            if success {
                completionHandler(nil)
            } else {
                completionHandler(WorkSpaceStorage.FSError.Unknown)
            }
        }
    }

    func removeItem(at: URL, completionHandler: @escaping (Error?) -> Void) {
        queue.async {
            let success = self.session.sftp.removeFile(atPath: at.path)
            if success {
                completionHandler(nil)
            } else {
                completionHandler(WorkSpaceStorage.FSError.Unknown)
            }
        }
    }

    func contents(at: URL, completionHandler: @escaping (Data?, Error?) -> Void) {
        queue.async {
            // TODO: Support OutputStream
            let data = self.session.sftp.contents(atPath: at.path)
            if data != nil {
                completionHandler(data, nil)
            } else {
                completionHandler(data, WorkSpaceStorage.FSError.Unknown)
            }
        }
    }

    func write(
        at: URL, content: Data, atomically: Bool, overwrite: Bool,
        completionHandler: @escaping (Error?) -> Void
    ) {
        queue.async {
            var content = content
            if content.isEmpty {
                content = "\n".data(using: .utf8)!
            }
            let success = self.session.sftp.writeContents(content, toFileAtPath: at.path)
            if success {
                completionHandler(nil)
            } else {
                completionHandler(WorkSpaceStorage.FSError.Unknown)
            }
        }
    }
}

extension SFTPFileSystemProvider: NMSSHSessionDelegate {
    func session(_ session: NMSSHSession, didDisconnectWithError error: Error) {
        didDisconnect(error)
    }
}
