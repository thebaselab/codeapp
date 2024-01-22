//
//  PortForwardContainer.swift
//  Code
//
//  Created by Ken Chung on 31/8/2023.
//

import SwiftUI

enum PortForwardServiceError: String {
    case portForwardServiceProviderUnavailable = "errors.port_forward.service_unavailable"
    case invalidAddress = "errors.port_forward.invalid_address"
}

extension PortForwardServiceError: LocalizedError {
    var errorDescription: String? {
        NSLocalizedString(self.rawValue, comment: "")
    }
}

struct PortForwardContainer: View {

    @EnvironmentObject var App: MainApp
    @State var ports: [RemotePortForwardSetup] = []

    func parseAddress(addressString: String) throws -> Address {
        let validPortRange = 1...65535
        if let port = Int(addressString),
            validPortRange ~= port
        {
            return Address(address: "127.0.0.1", port: port)
        }
        let parts = addressString.split(separator: ":")
        guard parts.count == 2,
            let port = Int(parts[1]),
            validPortRange ~= port
        else {
            throw PortForwardServiceError.invalidAddress
        }
        return Address(address: String(parts[0]), port: port)
    }

    func createPortForwardSetup(localAddressString: String, remoteAddressString: String)
        async throws
    {
        guard let serviceProvider = App.workSpaceStorage.portforwardServiceProvider else {
            throw PortForwardServiceError.portForwardServiceProviderUnavailable
        }
        let localAddress = try parseAddress(addressString: localAddressString)
        let remoteAddress = try parseAddress(addressString: remoteAddressString)
        _ = try await serviceProvider.bindLocalPortToRemote(
            localAddress: localAddress, remoteAddress: remoteAddress)
        loadPortForwardSetups()
    }

    func removePortForwardSetup(setup: RemotePortForwardSetup) {
        try? setup.socket.closeSocket()
        loadPortForwardSetups()
    }

    func loadPortForwardSetups() {
        guard let serviceProvider = App.workSpaceStorage.portforwardServiceProvider else {
            return
        }
        self.ports = serviceProvider.sockets.map {
            switch $0.type {
            case let .forward(localAddress, remoteAddress):
                return RemotePortForwardSetup(
                    label: "\(localAddress.port) -> \(remoteAddress.port)", socket: $0)
            }
        }
    }

    var body: some View {
        List {
            Group {
                RemotePortForwardListSection(
                    ports: ports,
                    removePortForwardSetup: removePortForwardSetup
                )
                RemotePortForwardCreateSection(
                    createPortForwardSetup: createPortForwardSetup
                )
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .onAppear {
                loadPortForwardSetups()
            }
            .padding(.horizontal, 10)
            .scrollIndicators(.hidden)
        }.listStyle(.grouped)
    }
}
