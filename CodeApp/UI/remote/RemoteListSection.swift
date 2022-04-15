//
//  RemoteList.swift
//  Code
//
//  Created by Ken Chung on 11/4/2022.
//

import SwiftUI

struct RemoteListSection: View {

    @EnvironmentObject var App: MainApp
    @State var servers: [URL]

    var body: some View {
        Section(header: Text("Remotes")) {
            ForEach(servers, id: \.absoluteString) { url in
                ServerCell(
                    url: url,
                    onRemove: {
                        if var hosts = UserDefaults.standard.stringArray(forKey: "remote.hosts") {
                            hosts.removeAll(where: { $0 == url.absoluteString })
                            servers = hosts.compactMap { URL(string: $0) }
                            UserDefaults.standard.set(hosts, forKey: "remote.hosts")

                            _ = KeychainAccessor.shared.removeCredentials(for: url)
                        }
                    })
            }
        }
    }
}
