//
//  activityBar.swift
//  Code
//
//  Created by Ken Chung on 8/5/2021.
//

import SwiftUI

struct activityBarItem: Identifiable {

    let id = UUID()
    let title: String
    let systemName: String
    let contextMenuItems: [contextMenuItem]
//    let view: AnyView

    struct contextMenuItem: Identifiable {
        let id = UUID()
        let title: String
        let action: (() -> Void)
        let systemName: String
    }
}

struct activityBar: View {

    @Binding var currentDirectory: UUID
    @Binding var isShowingDirectory: Bool

    @State var activityBarItems: [activityBarItem]

    static var width: CGFloat = 50.0

    var body: some View {
        VStack{
            ForEach(activityBarItems){item in
                Button(action: {

                }) {
                    ZStack{
                        // Let SwiftUI generate UIKeyCommand's discoverabilityTitle
                        Text(item.title)
                            .foregroundColor(.clear)
                            .font(.system(size: 1))

                        Image(systemName: item.systemName)
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(
                                Color.init(id: (currentDirectory == item.id && isShowingDirectory) ? "activityBar.foreground" : "activityBar.inactiveForeground")
                            )
                            .padding(5)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .hoverEffect(.highlight)
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .frame(minWidth: 0, maxWidth: activityBar.width, minHeight: 0, maxHeight: activityBar.width)
                .contextMenu{
                    ForEach(item.contextMenuItems){ menuItem in
                        Button(action: {
                            menuItem.action()
                        }){
                            Label(menuItem.title, systemImage: menuItem.systemName)
                        }
                    }
                }
            }
        }
    }
}

//struct activityBar_Previews: PreviewProvider {
//
//    @State static var isShowingDirectory = false
//    let currentDirectory: UUID
//    let activityBarItems: [activityBarItem]
//
//    init(){
//        let explorer = activityBarItem(title: "Show Explorer", systemName: "doc.on.doc", contextMenuItems: [], view: AnyView(explorer(showingNewFileSheet: .constant(false), showsDirectoryPicker: .constant(false))))
//        let search = activityBarItem(title: "Show Search", systemName: "magnifyingglass", contextMenuItems: [], view: AnyView(search()))
//        let git = activityBarItem(title: "Show Version Control", systemName: "chevron.left.slash.chevron.right", contextMenuItems: [], view: AnyView(git()))
//        activityBarItems = [explorer, search, git]
//        currentDirectory = explorer.id
//    }
//
//    static var previews: some View {
//        activityBar(currentDirectory: .constant(currentDirectory), isShowingDirectory: $isShowingDirectory, activityBarItems: activityBarItems)
//    }
//}
