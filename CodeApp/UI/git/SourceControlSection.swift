//
//  SourceControlView.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import SwiftUI

struct SourceControlSection: View {

    @EnvironmentObject var App: MainApp

    var body: some View {
        Section(
            header:
                Text("Source Control")
                .foregroundColor(Color.init("BW"))
        ) {
            RepositoryView()
        }
    }
}
