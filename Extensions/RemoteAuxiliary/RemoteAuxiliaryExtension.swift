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

        var portForwardActivityBarItem = ActivityBarItem(
            itemID: "REMOTE_PORT_FORWARD",
            iconSystemName: "point.3.filled.connected.trianglepath.dotted",
            title: "Port Forward",
            shortcutKey: nil,
            modifiers: nil,
            view: AnyView(PortForwardContainer()),
            contextMenuItems: nil,
            bubble: { nil },
            isVisible: {
                app.workSpaceStorage.remoteConnected
                    && app.workSpaceStorage.currentDirectory._url?.scheme == "sftp"
            }
        )
        portForwardActivityBarItem.positionPrecedence = -10
        contribution.activityBar.registerItem(item: portForwardActivityBarItem)
    }
}
