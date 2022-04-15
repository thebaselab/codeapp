//
//  StagedChangesSection.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import SwiftUI

struct StagedChangesSection: View {

    @EnvironmentObject var App: MainApp

    var body: some View {
        Section(
            header:
                Text(NSLocalizedString("Staged Changes", comment: ""))
                .foregroundColor(Color.init("BW"))
        ) {
            ForEach(Array(App.indexedResources.keys), id: \.self) { value in
                GitCell(itemUrl: value, isIndex: true)
                    .frame(height: 16)
            }
        }
    }
}
