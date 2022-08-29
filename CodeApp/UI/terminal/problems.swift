//
//  problems.swift
//  Code
//
//  Created by Ken Chung on 16/2/2021.
//

import SwiftUI

struct problemsView: View {

    @EnvironmentObject var App: MainApp

    @State private var expanded: Bool = true

    var body: some View {
        ScrollView {
            HStack {
                VStack {
                    ForEach(Array(App.problems.keys), id: \.self) { url in
                        DisclosureGroup(isExpanded: $expanded) {

                            ForEach(Array(App.problems[url]!), id: \.id) { marker in
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
                            fileIcon(url: url.absoluteString, iconSize: 14, type: .file)
                            Text(url.lastPathComponent).foregroundColor(Color.init("T1"))
                            Circle()
                                .fill(Color.init("panel.border"))
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Text("\(App.problems[url]!.count)").foregroundColor(
                                        Color.init("T1")
                                    ).font(.system(size: 10))
                                )
                        }

                    }
                }
                .font(.system(size: 12)).frame(maxHeight: .infinity).padding(.leading)
                Spacer()
            }
        }.frame(maxWidth: .infinity)
    }
}
