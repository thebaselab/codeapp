//
//  RemoteAuxiliaryExtension.swift
//  Code
//
//  Created by Ken Chung on 15/8/2023.
//

import SwiftUI

class RemoteAuxiliaryExtension: CodeAppExtension {
    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {
        let item = StatusBarItem(
            extensionID: "REMOTE_AUX",
            view: AnyView(RemoteConnectedLabel()),
            shouldDisplay: { app.workSpaceStorage.remoteConnected },
            positionPreference: .left,
            positionPrecedence: Int.min
        )
        contribution.statusBar.registerItem(item: item)
    }
}
