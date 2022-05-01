//
//  RemoteList.swift
//  Code
//
//  Created by Ken Chung on 11/4/2022.
//

import SwiftUI

struct RemoteListSection: View {

    @EnvironmentObject var App: MainApp
    @State var hosts: [RemoteHost]

    var body: some View {
        Section(header: Text("Remotes")) {

            if hosts.isEmpty {
                DescriptionText("You don't have any saved remote.")
            }

            ForEach(hosts, id: \.url) { host in
                ServerCell(
                    host: host,
                    onRemove: {
                        var remoteHosts = UserDefaults.standard.remoteHosts
                        remoteHosts.removeAll(where: { $0.url == host.url })
                        UserDefaults.standard.remoteHosts = remoteHosts
                        hosts = remoteHosts
                        _ = KeychainAccessor.shared.removeCredentials(for: host.url)
                    })
            }
        }
    }
}
