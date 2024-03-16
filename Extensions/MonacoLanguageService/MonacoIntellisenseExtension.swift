//
//  MonacoIntellisenseExtension.swift
//  Code
//
//  Created by Ken Chung on 16/2/2021.
//

import SwiftUI

class MonacoIntellisenseExtension: CodeAppExtension {
    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {
        let panel = Panel(
            labelId: "PROBLEMS",
            mainView: AnyView(PanelCodeMarkersSection()),
            toolBarView: nil
        )
        contribution.panel.registerPanel(panel: panel)
    }
}

private struct PanelCodeMarkersSection: View {

    @EnvironmentObject var App: MainApp

    var body: some View {
        Group {
            if App.problems.isEmpty {
                Text("panel.problems.no_problems_detected")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(Array(App.problems.keys), id: \.self) { url in
                            MarkersView(markers: App.problems[url]!, url: url)
                        }
                    }
                }.frame(maxWidth: .infinity).frame(maxHeight: .infinity)
            }
        }.font(.footnote)
    }
}

private struct MarkersView: View {

    let markers: [MonacoEditorMarker]
    let url: URL

    @State var expanded: Bool = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(markers, id: \.id) { marker in
                HStack(alignment: .top) {
                    switch marker.severity {
                    case 8:
                        Image(systemName: "xmark.circle").foregroundColor(.red)
                    case 1:
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.yellow)
                    case 2:
                        Image(systemName: "info.circle").foregroundColor(.blue)
                    case 4:
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.yellow)
                    default:
                        Image(systemName: "xmark.circle").foregroundColor(.red)
                    }

                    Text("\(marker.message)").foregroundColor(Color.init("T1"))
                        + Text(
                            " [\(marker.startLineNumber), \(marker.startColumn)]"
                        ).foregroundColor(Color.gray)

                    Spacer()
                }.padding(.leading, 20).padding(.vertical, 3)
            }
        } label: {
            FileIcon(url: url.absoluteString, iconSize: 14)
            Text(url.lastPathComponent).foregroundColor(Color.init("T1"))
            Circle()
                .fill(Color.init("panel.border"))
                .frame(width: 14, height: 14)
                .overlay(
                    Text("\(markers.count)").foregroundColor(
                        Color.init("T1")
                    ).font(.system(size: 10))
                )
        }
    }

}
