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
    @State private var accentColor: Color = .blue
    @FocusState private var searchBarFocused: Bool
    
    func returnSmallerInt(a:Int, b:Int) -> Int{
        if a>b {return b}
        else {return a}
    }
    
    private func binding(for key: String) -> Binding<Bool> {
        return .init(
            get: { App.textSearchManager.expansionStates[key, default: false] },
            set: { App.textSearchManager.expansionStates[key] = $0 })
    }
    
    var body: some View{
        VStack(alignment: .leading){
            List{
                Section(header:
                    Text(NSLocalizedString("Search", comment: ""))
                        .foregroundColor(Color.init("BW"))
                        
                ){
                    SearchBar(text: $App.textSearchManager.searchTerm, searchAction: {
                        if let path = URL(string: App.workSpaceStorage.currentDirectory.url)?.path{
                            App.textSearchManager.search(str: App.textSearchManager.searchTerm, path: path)
                        }
                    }, clearAction: {
                        App.textSearchManager.removeAllResults()
                    }, placeholder: NSLocalizedString("Search", comment: ""), cornerRadius: 15)
                    .focused($searchBarFocused)
                }
                
                Section(header:
                    HStack{
                        Text(NSLocalizedString("Results", comment: "") + " ")
                            .foregroundColor(Color.init("BW"))
                        Text(App.textSearchManager.message)
                            .foregroundColor(.gray)
                            .font(.system(size: 12, weight: .light))
                    }
                ){
                    if let mainFolderUrl = URL(string: App.workSpaceStorage.currentDirectory.url) {
                        ForEach(Array(App.textSearchManager.results.keys.sorted()), id: \.self){ key in
                            let fileURL = URL(fileURLWithPath: key)
                            
                            if let result = App.textSearchManager.results[key]{
                                DisclosureGroup(isExpanded: binding(for: key), content: {
                                    VStack(alignment: .leading, spacing: 2){
                                        ForEach(result){ res in
                                            HighlightedText(res.line, matching: App.textSearchManager.searchTerm, accentColor: accentColor)
                                                .foregroundColor(Color.init("T1"))
                                                .font(.custom("Menlo Regular", size: 14))
                                                .lineLimit(1)
                                                .onTapGesture {
                                                    App.openEditor(urlString: fileURL.absoluteString, type: .file)
                                                    App.monacoInstance.executeJavascript(command: "editor.focus()")
                                                    App.monacoInstance.searchByTerm(term: App.textSearchManager.searchTerm)
                                                    App.monacoInstance.scrollToLine(line: res.line_num)
                                                }
                                        }
                                    }
                                }, label:{
                                    VStack(alignment: .leading){
                                        HStack{
                                            fileIcon(url: key, iconSize: 10, type: .file)
                                            Text(editorDisplayName(editor: EditorInstance(url: key, content: "", type: .file)) + " ")
                                                .font(.system(size: 14, weight: .light))
                                                .foregroundColor(Color.init("T1"))
                                            Circle()
                                                .fill(Color.init("panel.border"))
                                                .frame(width: 14, height: 14)
                                                .overlay(
                                                    Text("\(result.count)").foregroundColor(Color.init("T1")).font(.system(size: 10))
                                                )
                                        }
                                        if let path = fileURL.deletingLastPathComponent().relativePath(from: mainFolderUrl),
                                           !path.isEmpty {
                                            Text(path)
                                                .foregroundColor(.gray)
                                                .font(.system(size: 10, weight: .light))
                                        }
                                        
                                    }
                                })
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
        }.onAppear{
            if App.textSearchManager.results.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6){
                    searchBarFocused = true
                }
            }
        }
    }
}
