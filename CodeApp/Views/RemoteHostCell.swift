//
//  RemoteHostCell.swift
//  Code
//
//  Created by Ken Chung on 11/4/2022.
//

import LocalAuthentication
import SwiftUI

struct RemoteHostCell: View {

    @EnvironmentObject var App: MainApp
    @State var showsPrompt = false

    let host: RemoteHost
    let onRemove: () -> Void
    let onConnect: (() -> Void) async throws -> Void
    let onConnectWithCredentials: (URLCredential) async throws -> Void

    var body: some View {
        HStack {
            Image(systemName: "server.rack")
                .foregroundColor(.gray)
            if let host = URL(string: host.url)?.host {
                Text(host)
            }
            Spacer()
            if App.workSpaceStorage.currentDirectory.url == host.url {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10)
            }
            if let scheme = URL(string: host.url)?.scheme,
                let type = RemoteType.init(rawValue: scheme)
            {
                RemoteTypeLabel(type: type)
            }
        }.onTapGesture {
            Task {
                try? await onConnect {
                    DispatchQueue.main.async {
                        showsPrompt = true
                    }
                }
            }
        }.sheet(isPresented: $showsPrompt) {
            RemoteAuthView(host: host) { username, password in
                let cred = URLCredential(
                    user: username, password: password, persistence: .forSession)

                Task {
                    try? await onConnectWithCredentials(cred)
                    showsPrompt = false
                }
            }
        }.contextMenu {
            Button {
                onRemove()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
