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
            Group {
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
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .environment(\.defaultMinListRowHeight, 10)
        .listStyle(SidebarListStyle())
    }
}
