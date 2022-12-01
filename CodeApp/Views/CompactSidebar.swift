//
//  CompactSidebar.swift
//  Code
//
//  Created by Ken Chung on 26/11/2022.
//

import SwiftUI

struct CompactSidebar: View {
    @EnvironmentObject var App: MainApp
    @EnvironmentObject var stateManager: MainStateManager

    @SceneStorage("sidebar.visible") var isSideBarVisible: Bool = DefaultUIState.SIDEBAR_VISIBLE
    @SceneStorage("sidebar.tab") var currentSideBarTab: SideBarSection = DefaultUIState.SIDEBAR_TAB

    let sections: [SideBarSection: (LocalizedStringKey, String)] = [
        .explorer: ("Explorer", "doc.on.doc"),
        .search: ("Search", "magnifyingglass"),
        .sourceControl: (
            "source_control.title", "point.topleft.down.curvedto.point.bottomright.up"
        ),
        .remote: ("Remotes", "rectangle.connected.to.line.below"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            VStack {
                HStack {
                    Button(action: {
                        withAnimation(.easeIn(duration: 0.2)) {
                            isSideBarVisible.toggle()
                        }
                    }) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 17))
                            .foregroundColor(Color.init("T1"))
                            .padding(5)
                            .contentShape(
                                RoundedRectangle(
                                    cornerRadius: 8, style: .continuous)
                            )
                            .hoverEffect(.highlight)
                            .frame(
                                minWidth: 0, maxWidth: 20, minHeight: 0,
                                maxHeight: 20
                            )
                            .padding()
                    }.sheet(isPresented: $stateManager.showsNewFileSheet) {
                        NewFileView(
                            targetUrl: App.workSpaceStorage
                                .currentDirectory.url
                        ).environmentObject(App)
                    }

                    Spacer()

                }
                .overlay {
                    Menu {
                        Picker(
                            selection: $currentSideBarTab,
                            label: Text("Section")
                        ) {
                            ForEach(
                                [
                                    SideBarSection.explorer,
                                    SideBarSection.search,
                                    SideBarSection.sourceControl,
                                    SideBarSection.remote,
                                ], id: \.self
                            ) { value in
                                Label(
                                    sections[value]!.0,
                                    systemImage: sections[value]!.1)
                            }
                        }
                    } label: {
                        HStack {
                            Text(sections[currentSideBarTab]?.0 ?? "")
                                .bold()
                                .lineLimit(1)
                                .foregroundColor(Color.init("T1"))

                            Image(systemName: "chevron.down.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                        }.frame(width: 200.0)
                    }
                }
                .background(
                    Color.init(id: "sideBar.background")
                        .ignoresSafeArea(.container, edges: .top)
                )
                .frame(height: 40)

                Group {
                    switch currentSideBarTab {
                    case .explorer:
                        ExplorerContainer()
                    case .search:
                        SearchContainer()
                    case .sourceControl:
                        SourceControlContainer()
                    case .remote:
                        RemoteContainer()
                    }
                }.background(Color.init(id: "sideBar.background"))

            }
            .frame(width: 280.0)
            .background(Color.init(id: "sideBar.background"))

            ZStack {
                Color.black.opacity(0.001)
                Spacer()
            }.onTapGesture {
                withAnimation(.easeIn(duration: 0.2)) {
                    isSideBarVisible.toggle()
                }
            }
        }
    }
}
