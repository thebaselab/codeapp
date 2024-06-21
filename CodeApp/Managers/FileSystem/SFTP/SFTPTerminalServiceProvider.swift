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
    private var onRequestInteractiveKeyboard: ((String) async -> String)
    private let queue = DispatchQueue(label: "terminal.serial.queue")

    init?(
        baseURL: URL, username: String,
        onRequestInteractiveKeyboard: @escaping ((String) async -> String)
    ) {
        guard baseURL.scheme == "sftp",
            let host = baseURL.host,
            let port = baseURL.port
        else {
            return nil
        }
        self.onRequestInteractiveKeyboard = onRequestInteractiveKeyboard
        super.init()

        queue.async {
            self.session = NMSSHSession(host: host, port: port, andUsername: username)
            self.session.delegate = self
            self.session.channel.delegate = self
        }
    }

    func connect(
        authentication: RemoteAuthenticationMode
    ) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                self.session.connect()
                self.session.timeout = 10

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
                            _privateKeyURL
                            ?? getRootDirectory().appendingPathComponent(".ssh/id_rsa")
                        if let privateKeyContent = try? String(contentsOf: privateKeyURL) {
                            self.session.authenticateBy(
                                inMemoryPublicKey: nil, privateKey: privateKeyContent,
                                andPassword: credentials.password)
                        }
                    }
                }

                if !self.session.isAuthorized {
                    self.session.authenticateByKeyboardInteractive()
                }

                guard self.session.isConnected && self.session.isAuthorized else {
                    continuation.resume(throwing: SFTPError.AuthFailure)
                    return
                }

                do {
                    self.session.channel.requestPty = true
                    self.session.channel.ptyTerminalType = .xterm
                    try self.session.channel.startShell()
                } catch {
                    print("Unable to start shell,", error)
                    continuation.resume(throwing: SFTPError.UnableToStartShell)
                }

                continuation.resume()
            }
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
    func session(_ session: NMSSHSession, didDisconnectWithError error: Error) {
        didDisconnect?()
    }

    func session(_ session: NMSSHSession, keyboardInteractiveRequest request: String) -> String {
        return UnsafeTask {
            await self.onRequestInteractiveKeyboard(request)
        }.get()
    }
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
