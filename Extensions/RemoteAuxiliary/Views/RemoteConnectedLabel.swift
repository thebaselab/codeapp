//
//  RemoteConnectedLabel.swift
//  Code
//
//  Created by Ken Chung on 15/8/2023.
//

import SwiftUI

struct RemoteConnectedLabel: View {

    @EnvironmentObject var App: MainApp

    var body: some View {
        HStack {
            Image(systemName: "rectangle.connected.to.line.below")
                .font(.system(size: 10))
            Text(App.workSpaceStorage.remoteHost ?? "")
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 3)
    }
}
