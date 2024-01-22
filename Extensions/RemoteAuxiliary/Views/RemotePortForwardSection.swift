//
//  RemotePortForwardSection.swift
//  Code
//
//  Created by Ken Chung on 31/8/2023.
//

import SwiftUI

struct RemotePortForwardSetup: Identifiable {
    var id: UUID = UUID()
    var label: String
    var socket: any PortForwardSocket
}

struct RemotePortForwardCreateSection: View {

    var createPortForwardSetup: (String, String) async throws -> Void

    @EnvironmentObject var App: MainApp
    @State var localAddress: String = ""
    @State var remoteAddress: String = ""

    var body: some View {
        Section(
            header:
                Text("remote.port_forward.new_port_forward")
                .foregroundColor(Color(id: "sideBarSectionHeader.foreground"))
        ) {

            Group {
                TextField("remote.port_forward.local_port_or_address", text: $localAddress)
                TextField("remote.port_forward.remote_port_or_address", text: $remoteAddress)
            }
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .padding(7)
            .background(Color.init(id: "input.background"))
            .cornerRadius(10)

            DescriptionText("remote.port_forward.address_example")

            SideBarButton("common.add") {
                Task {
                    do {
                        try await createPortForwardSetup(localAddress, remoteAddress)
                        localAddress = ""
                        remoteAddress = ""
                    } catch let error as NSError {
                        if let code = (error.underlyingErrors.first as? NSError)?.code,
                            code == EADDRINUSE
                        {
                            App.notificationManager.showErrorMessage(
                                "errors.port_forward.address_already_in_use")
                        } else {
                            App.notificationManager.showErrorMessage(
                                error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
}

struct RemotePortForwardListSection: View {

    var ports: [RemotePortForwardSetup]
    var removePortForwardSetup: (RemotePortForwardSetup) -> Void

    var body: some View {
        Section(
            header:
                Text("remote.port_forward.port_forwarding")
                .foregroundColor(Color(id: "sideBarSectionHeader.foreground"))
        ) {
            if ports.isEmpty {
                DescriptionText("remote.port_forward.configure_description")
            } else {
                ForEach(ports) { port in
                    Menu {
                        Section {
                            Button(role: .destructive) {
                                removePortForwardSetup(port)
                            } label: {
                                Label("common.remove", systemImage: "xmark")
                            }
                        } header: {
                            Text(port.label)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "point.3.connected.trianglepath.dotted")
                            Text(port.label)
                            Spacer()
                            Circle()
                                .fill(.green)
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }

        }
    }
}
