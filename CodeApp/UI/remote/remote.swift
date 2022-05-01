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

    @State var hosts: [RemoteHost]

    init() {
        hosts = UserDefaults.standard.remoteHosts
    }

    var body: some View {
        List {
            if App.workSpaceStorage.remoteConnected {
                RemoteConnectedSection()
            } else {
                RemoteListSection(hosts: hosts)
                CreateRemoteSection(hosts: $hosts)
            }
        }.listStyle(SidebarListStyle())
    }
}
