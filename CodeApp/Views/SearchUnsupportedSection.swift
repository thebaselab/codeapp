//
//  SearchUnsupportedSection.swift
//  Code
//
//  Created by Ken Chung on 15/4/2022.
//

import SwiftUI

struct SearchUnsupportedSection: View {
    var body: some View {
        Section(
            header:
                Text("Search")
                .foregroundColor(Color(id: "sideBarSectionHeader.foreground"))
        ) {
            DescriptionText("The current workspace does not support global search.")
        }
    }
}
