//
//  SourceControlCreateBranchAlert.swift
//  Code
//
//  Created by Ken Chung on 21/8/2023.
//

import SwiftUI

struct SourceControlCreateBranchAlert: View {

    @State var branchName: String = ""
    var onCreateBranch: (String) -> Void

    var body: some View {
        Group {
            TextField("source_control.branch_name", text: $branchName)
            Button("common.create") {
                onCreateBranch(branchName)
                branchName = ""
            }
            Button("common.cancel", role: .cancel) {}
        }
    }
}
