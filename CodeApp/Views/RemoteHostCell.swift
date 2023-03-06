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
    @State var isRenaming = false
    @State var newName = ""
    @FocusState var focusedField: Field?

    enum Field {
        case rename
    }

    let host: RemoteHost
    let onRemove: () -> Void
    let onConnect: (@escaping () -> Void) async throws -> Void
    let onConnectWithCredentials: (URLCredential) async throws -> Void
    let onRenameHost: (String) -> Void

    var body: some View {
        HStack {
            Image(systemName: "server.rack")
                .foregroundColor(.gray)

            if isRenaming {
                TextField("Remote name", text: $newName, prompt: Text(host.rowDisplayName))
                    .onSubmit {
                        onRenameHost(newName)
                        isRenaming = false
                    }
                    .focused($focusedField, equals: .rename)
            } else {
                Text(host.rowDisplayName)
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
            guard !isRenaming else { return }
            Task {
                try? await onConnect {
                    DispatchQueue.main.async {
                        showsPrompt = true
                    }
                }
            }
        }.sheet(isPresented: $showsPrompt) {
            RemoteAuthView(host: host) { username, password in
                showsPrompt = false

                let cred = URLCredential(
                    user: username, password: password, persistence: .forSession)
                Task {
                    try? await onConnectWithCredentials(cred)
                }
            }
        }.contextMenu {

            Button {
                isRenaming.toggle()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    focusedField = .rename
                }

            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
