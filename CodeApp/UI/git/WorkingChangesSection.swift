//
//  WorkingChangesSection.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import SwiftUI

struct WorkingChangesSection: View {

    @EnvironmentObject var App: MainApp

    var body: some View {
        Section(
            header:
                Text("Changes")
                .foregroundColor(Color.init("BW"))
        ) {
            if App.workingResources.isEmpty {
                DescriptionText("No changes are made in the working directory.")
            }
            ForEach(Array(App.workingResources.keys), id: \.self) { value in
                GitCell(itemUrl: value, isIndex: false)
                    .frame(height: 16)
            }
        }
    }
}
