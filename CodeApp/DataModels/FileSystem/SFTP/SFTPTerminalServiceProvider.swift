//
//  SFTPTerminalServiceProvider.swift
//  Code
//
//  Created by Ken Chung on 3/5/2022.
//

import Foundation
import NMSSH

class SFTPTerminalServiceProvider: NSObject, TerminalServiceProvider {
    private var session: NMSSHSession
    private var didDisconnect: (Error) -> Void

    private var onStdout: ((Data) -> Void)? = nil
    private var onStderr: ((Data) -> Void)? = nil

    init?(baseURL: URL, cred: URLCredential, didDisconnect: @escaping (Error) -> Void) {
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
    }

    public func kill() {
        // Write Ctrl-D
    }

    public func setWindowsSize(cols: Int, rows: Int) {
        session.channel.requestSizeWidth(UInt(cols), height: UInt(rows))
    }

    public func write(data: Data) {
        do {
            try session.channel.write(data)
        } catch {
            print(error.localizedDescription)
        }
    }

    public func onStdout(callback: @escaping (Data) -> Void) {
        self.onStdout = callback
    }

    public func onStderr(callback: @escaping (Data) -> Void) {
        self.onStderr = callback
    }
}

extension SFTPTerminalServiceProvider: NMSSHSessionDelegate {

}

extension SFTPTerminalServiceProvider: NMSSHChannelDelegate {
    func channel(_ channel: NMSSHChannel, didReadRawData data: Data) {
        onStdout?(data)
    }

    func channel(_ channel: NMSSHChannel, didReadRawError error: Data) {
        onStderr?(error)
    }
}
