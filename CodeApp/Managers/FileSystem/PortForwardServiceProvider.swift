//
//  PortForwardServiceProvider.swift
//  Code
//
//  Created by Ken Chung on 31/8/2023.
//

import Foundation

struct Address {
    var address: String
    var port: Int
}

enum PortForwardType {
    // Local Address, Remote Address
    case forward(Address, Address)
}

protocol PortForwardSocket {
    var type: PortForwardType { get }
    func closeSocket() throws
}

protocol PortForwardServiceProvider {
    associatedtype Socket: PortForwardSocket
    var sockets: [Socket] { get }
    func bindLocalPortToRemote(localAddress: Address, remoteAddress: Address) async throws -> Socket
    func onSocketClosed(_ callback: @escaping (Socket) -> Void)
}
