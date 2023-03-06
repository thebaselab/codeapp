//
//  SFTPTerminalServiceProvider.swift
//  Code
//
//  Created by Ken Chung on 3/5/2022.
//

import Foundation
import NMSSH

class SFTPTerminalServiceProvider: NSObject, TerminalServiceProvider {
    private var session: NMSSHSession!
    private var didDisconnect: (() -> Void)? = nil

    private var onStdout: ((Data) -> Void)? = nil
    private var onStderr: ((Data) -> Void)? = nil
    private let queue = DispatchQueue(label: "terminal.serial.queue")

    init?(baseURL: URL, cred: URLCredential) {
        guard baseURL.scheme == "sftp",
            let host = baseURL.host,
            let port = baseURL.port,
            let username = cred.user
        else {
            return nil
        }
        super.init()

        queue.async {
            self.session = NMSSHSession(host: host, port: port, andUsername: username)
            self.session.delegate = self
            self.session.channel.delegate = self
        }
    }

    func connect(
        authentication: RemoteAuthenticationMode,
        completionHandler: @escaping (Error?) -> Void
    ) {
        queue.async {
            self.session.connect()

            if self.session.isConnected {
                switch authentication {
                case .plainUsernamePassword(let credentials):
                    self.session.authenticate(byPassword: credentials.password ?? "")

                case .inMemorySSHKey(let credentials, let privateKeyContent):
                    self.session.authenticateBy(
                        inMemoryPublicKey: nil, privateKey: privateKeyContent,
                        andPassword: credentials.password)

                case .inFileSSHKey(let credentials, let _privateKeyURL):
                    let privateKeyURL =
                        _privateKeyURL ?? getRootDirectory().appendingPathComponent(".ssh/id_rsa")
                    if let privateKeyContent = try? String(contentsOf: privateKeyURL) {
                        self.session.authenticateBy(
                            inMemoryPublicKey: nil, privateKey: privateKeyContent,
                            andPassword: credentials.password)
                    }
                }
            }

            guard self.session.isConnected && self.session.isAuthorized else {
                completionHandler(WorkSpaceStorage.FSError.AuthFailure)
                return
            }

            do {
                self.session.channel.requestPty = true
                self.session.channel.ptyTerminalType = .xterm
                try self.session.channel.startShell()
            } catch {
                print("Unable to start shell,", error)
            }

            completionHandler(nil)
        }

    }

    func disconnect() {
        queue.async {
            self.session.channel.closeShell()
            self.session.disconnect()
        }
        didDisconnect?()
    }

    public func kill() {
        // Write Ctrl-D
    }

    public func setWindowsSize(cols: Int, rows: Int) {
        session.channel.requestSizeWidth(UInt(cols), height: UInt(rows))
    }

    public func write(data: Data) {
        queue.async {
            var err: NSError?
            self.session.channel.write(data, error: &err, timeout: 1)
        }
    }

    public func onStdout(callback: @escaping (Data) -> Void) {
        self.onStdout = callback
    }

    public func onStderr(callback: @escaping (Data) -> Void) {
        self.onStderr = callback
    }

    public func onDisconnect(callback: @escaping () -> Void) {
        self.didDisconnect = callback
    }
}

extension SFTPTerminalServiceProvider: NMSSHSessionDelegate {
}

extension SFTPTerminalServiceProvider: NMSSHChannelDelegate {

    // func session(_ session: NMSSHSession, keyboardInteractiveRequest request: String) -> String {
    //     print("request received: \(request)")
    //     return ""
    // }

    // func channel(_ channel: NMSSHChannel, didReadError error: String) {
    //     print("didReadError", error)
    // }

    // func channel(_ channel: NMSSHChannel, didReadData message: String) {

    //     print("didReadData", message)
    // }

    func channel(_ channel: NMSSHChannel, didReadRawData data: Data) {
        onStdout?(data)
    }

    func channel(_ channel: NMSSHChannel, didReadRawError error: Data) {
        onStderr?(error)
    }
}
