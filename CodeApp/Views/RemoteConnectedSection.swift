//
//  RemoteConnectedView.swift
//  Code
//
//  Created by Ken Chung on 11/4/2022.
//

import SwiftUI

struct RemoteConnectedSection: View {

    @EnvironmentObject var App: MainApp

    var body: some View {
        Section(
            header:
                Text("Current Remote")
                .foregroundColor(Color(id: "sideBarSectionHeader.foreground"))
        ) {
            DescriptionText("Connected to \(App.workSpaceStorage.remoteHost ?? "server.")")

            if let fingerPrint = App.workSpaceStorage.remoteFingerprint {
                DescriptionText("Fingerprint: \(fingerPrint)")
            }

            SideBarButton("Disconnect") {
                App.workSpaceStorage.disconnect()
            }
        }
    }
}
