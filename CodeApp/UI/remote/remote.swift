//
//  remote.swift
//  remote
//
//  Created by Ken Chung on 8/8/2021.
//

import FilesProvider
import LocalAuthentication
import SwiftUI

struct remote: View {

    @EnvironmentObject var App: MainApp

    @State var servers: [URL]

    init() {
        if let hosts = UserDefaults.standard.stringArray(forKey: "remote.hosts") {
            servers = hosts.compactMap { URL(string: $0) }
        } else {
            servers = []
        }
    }

    var body: some View {
        List {
            if App.workSpaceStorage.remoteConnected {
                RemoteConnectedSection()
            } else {
                RemoteListSection(servers: servers)
                CreateRemoteSection(servers: $servers)
            }
        }.listStyle(SidebarListStyle())
    }
}
