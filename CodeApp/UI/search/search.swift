//
//  search.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI
import ios_system

struct search: View {

    @EnvironmentObject var App: MainApp

    var body: some View {
        VStack(alignment: .leading) {
            List {
                Group {
                    if App.workSpaceStorage.remoteConnected {
                        SearchUnsupportedSection()
                    } else {
                        SearchSection()
                        ResultsSection()
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(SidebarListStyle())
        }
    }
}
