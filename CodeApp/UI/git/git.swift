//
//  git.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

struct git: View {

    @EnvironmentObject var App: MainApp

    var body: some View {
        List {
            if App.workSpaceStorage.gitServiceProvider == nil {
                SourceControlUnsupportedSection()
            } else if App.gitTracks.count > 0 || App.branch != "" {
                SourceControlSection()
                if !App.indexedResources.isEmpty {
                    StagedChangesSection()
                }
                WorkingChangesSection()
            } else {
                EmptySourceControlSection()
                CloneRepositorySection()
            }
        }
        .environment(\.defaultMinListRowHeight, 10)
        .listStyle(SidebarListStyle())
    }
}
