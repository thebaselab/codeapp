//
//  SFTPFileSystemProvider.swift
//  Code
//
//  Created by Ken Chung on 13/4/2022.
//

import Foundation
import NMSSH

enum SFTPError: String {
    case InvalidHostURL = "errors.sftp.invalid_host_url"
    case InvalidJumpHostURL = "errors.sftp.invalid_jump_host_url"
    case UnableToStartPortforwardService = "errors.sftp.unable_to_start_portforward_service"
    case AuthFailure = "errors.sftp.auth_failure"
    // TODO: Expose libssh2_sftp_last_error
    case FailedToPerformOperation = "errors.sftp.failed_to_perform_operation"
    case UnableToStartShell = "errors.sftp.unable_to_start_shell"
}

extension SFTPError: LocalizedError {
    var errorDescription: String? {
        NSLocalizedString(self.rawValue, comment: "")
    }
}

struct SFTPSocket: PortForwardSocket {
    var socket: NMSSHSocket
    var type: PortForwardType

    func closeSocket() throws {
        close(socket.sock)
    }
}

struct SFTPJumpHost {
    var url: URL
    var username: String
    var authentication: RemoteAuthenticationMode
}

class SFTPFileSystemProvider: NSObject {
    static var registeredScheme: String = "sftp"
    var gitServiceProvider: GitServiceProvider? = nil
    var searchServiceProvider: SearchServiceProvider? = nil
    var terminalServiceProvider: TerminalServiceProvider? {
        _terminalServiceProvider
    }
    var _terminalServiceProvider: SFTPTerminalServiceProvider? = nil
    var portforwardServiceProvider: (any PortForwardServiceProvider)? { self }

    var fingerPrint: String? = nil
    var sockets: [SFTPSocket] = []

    private var didDisconnect: (Error) -> Void
    private var onSocketClosed: ((SFTPSocket) -> Void)? = nil
    private var onTerminalData: ((Data) -> Void)? = nil
    private var onRequestInteractiveKeyboard: ((String) async -> String)
    private var session: NMSSHSession!
    private let queue = DispatchQueue(label: "sftp.serial.queue")
    private var jumpHostFSS: [SFTPFileSystemProvider] = []

    init?(
        baseURL: URL, username: String, didDisconnect: @escaping (Error) -> Void,
        onRequestInteractiveKeyboard: @escaping ((String) async -> String),
        onTerminalData: ((Data) -> Void)?
    ) {
        self.didDisconnect = didDisconnect
        self.onTerminalData = onTerminalData
        self.onRequestInteractiveKeyboard = onRequestInteractiveKeyboard
        super.init()

        do {
            try configureSession(baseURL: baseURL, username: username)
            try configureTerminalSession(baseURL: baseURL, username: username)
        } catch {
            return nil
        }
    }

    deinit {
        sockets.forEach { try? $0.closeSocket() }
        self._terminalServiceProvider?.disconnect()
        self.session.sftp.disconnect()
        self.session.disconnect()
    }

    private func configureTerminalSession(baseURL: URL, username: String) throws {
        self._terminalServiceProvider = SFTPTerminalServiceProvider(
            baseURL: baseURL, username: username,
            onRequestInteractiveKeyboard: onRequestInteractiveKeyboard)
        guard self._terminalServiceProvider != nil else {
            throw SFTPError.InvalidHostURL
        }
        if let onTerminalData = self.onTerminalData {
            self._terminalServiceProvider?.onStderr(callback: onTerminalData)
            self._terminalServiceProvider?.onStdout(callback: onTerminalData)
        }
    }

    private func configureSession(baseURL: URL, username: String) throws {
        guard baseURL.scheme == "sftp",
            let host = baseURL.host,
            let port = baseURL.port
        else {
            throw SFTPError.InvalidHostURL
        }
        queue.sync {
            self.session = NMSSHSession(host: host, port: port, andUsername: username)
            self.session.delegate = self
            self.session.channel.socketDelegate = self
        }
    }

    func connect(
        authentication: RemoteAuthenticationMode,
        jumpHost: SFTPJumpHost?
    ) async throws {
        if let jumpHost {
            let (sftpURL, terminalURL) = try await configureJumpHost(jumpHost: jumpHost)
            try configureSession(baseURL: sftpURL, username: session.username)
            try configureTerminalSession(baseURL: terminalURL, username: session.username)
        }

        try await self._terminalServiceProvider?.connect(authentication: authentication)
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

                self.fingerPrint = self.session.fingerprint(self.session.fingerprintHash)
                continuation.resume()

                // This might blocks for 10 seconds on servers without SFTP support
                // early resume to prevent prolonged connection
                self.session.sftp.connect()
            }
        }
    }

    private func configureJumpHost(jumpHost: SFTPJumpHost) async throws -> (URL, URL) {
        guard
            let primaryJumpServerFS = SFTPFileSystemProvider(
                baseURL: jumpHost.url,
                username: jumpHost.username,
                didDisconnect: didDisconnect,
                onRequestInteractiveKeyboard: self.onRequestInteractiveKeyboard,
                onTerminalData: nil
            ),
            let secondaryJumpServerFS = SFTPFileSystemProvider(
                baseURL: jumpHost.url,
                username: jumpHost.username,
                didDisconnect: didDisconnect,
                onRequestInteractiveKeyboard: self.onRequestInteractiveKeyboard,
                onTerminalData: nil
            )
        else {
            throw SFTPError.InvalidJumpHostURL
        }

        async let r1: Void = primaryJumpServerFS.connect(
            authentication: jumpHost.authentication,
            jumpHost: nil)
        async let r2: Void = secondaryJumpServerFS.connect(
            authentication: jumpHost.authentication,
            jumpHost: nil)
        _ = try await (r1, r2)

        guard
            let primaryPortForwardServiceProvider = primaryJumpServerFS
                .portforwardServiceProvider,
            let secondaryPortForwardServiceProvider = secondaryJumpServerFS
                .portforwardServiceProvider
        else {
            throw SFTPError.UnableToStartPortforwardService
        }
        let port1 = Int.random(in: 49152...65535)
        let port2 = Int.random(in: 49152...65535)
        async let r3 = primaryPortForwardServiceProvider.bindLocalPortToRemote(
            localAddress: Address(address: "127.0.0.1", port: port1),
            remoteAddress: Address(address: session.host, port: Int(truncating: session.port))
        )
        async let r4 = secondaryPortForwardServiceProvider.bindLocalPortToRemote(
            localAddress: Address(address: "127.0.0.1", port: port2),
            remoteAddress: Address(address: session.host, port: Int(truncating: session.port))
        )
        _ = try await (r3, r4)

        // Add reference jumpServerFS before its scope ends so it does not get deallocated
        self.jumpHostFSS = [primaryJumpServerFS, secondaryJumpServerFS]

        return (
            URL(string: "sftp://127.0.0.1:\(String(port1))")!,
            URL(string: "sftp://127.0.0.1:\(String(port2))")!
        )
    }
}

extension SFTPFileSystemProvider: NMSSHSessionDelegate {
    func session(_ session: NMSSHSession, didDisconnectWithError error: Error) {
        didDisconnect(error)
    }

    func session(_ session: NMSSHSession, keyboardInteractiveRequest request: String) -> String {
        return UnsafeTask {
            await self.onRequestInteractiveKeyboard(request)
        }.get()
    }
}

extension SFTPFileSystemProvider: NMSSHSocketDelegate {
    func socketDidClose(_ socket: NMSSHSocket) {
        let sftpSocket = sockets.first { $0.socket.sock == socket.sock }
        sockets = sockets.filter { $0.socket.sock != socket.sock }
        if let sftpSocket {
            self.onSocketClosed?(sftpSocket)
        }
    }
}

extension SFTPFileSystemProvider: FileSystemProvider {
    func contentsOfDirectory(at url: URL, completionHandler: @escaping ([URL]?, Error?) -> Void) {
        queue.async {
            let files = self.session.sftp.contentsOfDirectory(atPath: url.path)
            guard let files = files else {
                completionHandler(nil, SFTPError.FailedToPerformOperation)
                return
            }
            completionHandler(
                files.map {
                    // Resolve symbolic link to determine if it points to a directory
                    // TODO: Evaluate the performance penalty
                    if $0.isSymbolicLink,
                        let realPath = self.session.sftp.resolveSymbolicLink(
                            atPath: url.appendingPathComponent($0.filename).path),
                        let info = self.session.sftp.infoForFile(atPath: realPath),
                        info.isDirectory
                    {
                        return url.appendingPathComponent($0.filename + "/")
                    }
                    return url.appendingPathComponent($0.filename)
                }, nil)
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
                completionHandler(SFTPError.FailedToPerformOperation)
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
                completionHandler(SFTPError.FailedToPerformOperation)
            }
        }
    }

    private func copyItemFromRemoteToLocal(
        at: URL, to: URL, completionHandler: @escaping (Error?) -> Void
    ) {
        queue.async {
            let data = self.session.sftp.contents(atPath: at.path)

            guard let data = data else {
                completionHandler(SFTPError.FailedToPerformOperation)
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
                completionHandler(SFTPError.FailedToPerformOperation)
            }
        }
    }

    func removeItem(at: URL, completionHandler: @escaping (Error?) -> Void) {
        queue.async {
            let success = self.session.sftp.removeFile(atPath: at.path)
            if success {
                completionHandler(nil)
            } else {
                completionHandler(SFTPError.FailedToPerformOperation)
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
                completionHandler(data, SFTPError.FailedToPerformOperation)
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
                completionHandler(SFTPError.FailedToPerformOperation)
            }
        }
    }

    func attributesOfItem(
        at: URL, completionHandler: @escaping ([FileAttributeKey: Any?]?, Error?) -> Void
    ) {
        queue.async {
            guard let attributes = self.session.sftp.infoForFile(atPath: at.path) else {
                completionHandler(nil, SFTPError.FailedToPerformOperation)
                return
            }

            completionHandler(
                [
                    .modificationDate: attributes.modificationDate,
                    .size: attributes.fileSize,
                ], nil)
        }
    }

    func resolveSymbolicLink(atPath: String) async -> String? {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(
                    returning:
                        self.session.sftp.resolveSymbolicLink(atPath: atPath)
                )

            }
        }

    }
}

extension SFTPFileSystemProvider: PortForwardServiceProvider {
    func bindLocalPortToRemote(localAddress: Address, remoteAddress: Address) async throws
        -> SFTPSocket
    {
        return try await withUnsafeThrowingContinuation { continuation in
            queue.async {
                do {
                    let socket = NMSSHChannel.createSocket()
                    try self.session.channel.bindLocalPortToRemoteHost(
                        with: socket,
                        localListenIP: localAddress.address,
                        localPort: localAddress.port,
                        host: remoteAddress.address,
                        port: remoteAddress.port,
                        in: self.queue
                    )
                    let sftpSocket = SFTPSocket(
                        socket: socket, type: .forward(localAddress, remoteAddress))
                    DispatchQueue.main.async {
                        self.sockets.append(sftpSocket)
                    }
                    continuation.resume(returning: sftpSocket)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func onSocketClosed(_ callback: @escaping (SFTPSocket) -> Void) {
        self.onSocketClosed = callback
    }
}
