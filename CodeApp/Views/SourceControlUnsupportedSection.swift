//
//  UnsupportedSourceControlView.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import SwiftUI

struct SourceControlUnsupportedSection: View {
    var body: some View {
        Section(
            header:
                Text("source_control.title")
                .foregroundColor(Color(id: "sideBarSectionHeader.foreground"))
        ) {
            DescriptionText("The current workspace does not support source control.")
        }
    }
}
