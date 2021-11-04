//
//  main.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI
import UIKit
import ios_system
import CoreSpotlight

struct mainView: View{
    
    @EnvironmentObject var App: MainApp
    
    @State var showChangeLog: Bool
    @State var isShowingDirectory: Bool
    @State var currentDirectory: Int
    @State var showsPanel: Bool
    @State var currentPanelTab: Int
    
    @State var showingSettingsSheet: Bool = false
    @State var showingNewFileSheet: Bool = false
    @State var showsDirectoryPicker: Bool = false
    @State var showsFilePicker: Bool = false
    @State var showSafari: Bool = false
    
    @State var panelHeight: CGFloat = 200.0
    @State var panelShowSplitView: Bool = false
    @State var panelShowingInput: Bool = false
    
    @State var isShowingCheckoutAlert: Bool = false
    @State var selectedBranch: GitServiceProvider.checkoutDest? = nil
    @State var checkoutDetached: Bool = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment (\.colorScheme) var colorScheme: ColorScheme
    
    @AppStorage("accentColor") var accentColor: String = "blue"
    @AppStorage("editorFontSize") var editorTextSize: Int = 14
    @AppStorage("editorReadOnly") var editorReadOnly = false
    @AppStorage("compilerShowPath") var compilerShowPath = false
    
    let sections: [Int:[String]] = [0: ["Files", "doc.on.doc"], 1: ["Search", "magnifyingglass"], 3: ["Source Control", "point.topleft.down.curvedto.point.bottomright.up"], 4: ["Remotes", "rectangle.connected.to.line.below"]]
    
    init(){
        _isShowingDirectory = State.init(initialValue: UserDefaults.standard.bool(forKey: "mainView.sideBarEnabled"))
        _currentDirectory = State.init(initialValue: UserDefaults.standard.integer(forKey: "mainView.sideBarIndex"))
        _showsPanel = State.init(initialValue: UserDefaults.standard.bool(forKey: "mainView.panelEnabled"))
        if UserDefaults.standard.object(forKey: "mainView.panelIndex") != nil {
            _currentPanelTab = State.init(initialValue: UserDefaults.standard.integer(forKey: "mainView.panelIndex"))
        }else{
            _currentPanelTab = State.init(initialValue: 2)
        }
        
        if let lastReadVersion = UserDefaults.standard.string(forKey: "changelog.lastread"){
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
            if lastReadVersion != currentVersion{
                _showChangeLog = State(initialValue: true)
                UserDefaults.standard.setValue(currentVersion, forKey: "changelog.lastread")
                return
            }else{
                _showChangeLog = State(initialValue: false)
            }
        }else{
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
            UserDefaults.standard.setValue(currentVersion, forKey: "changelog.lastread")
            _showChangeLog = State(initialValue: true)
            return
        }
    }
    
    func returnBarSize() -> CGFloat {
        return 50.0
    }
    
    func openFolder(){
        self.isShowingDirectory = true
        self.showsDirectoryPicker = true
    }
    
    func openFile(){
        self.showsFilePicker.toggle()
    }
    
    func openNewFile(){
        self.showingNewFileSheet.toggle()
    }
    
    func openConsolePanel(){
        if(self.panelHeight < 70){
            self.panelHeight = 200
        }
        self.showsPanel.toggle()
        App.terminalInstance.webView?.becomeFirstResponder()
    }
    
    func openSidePanel(index: Int){
        if(!isShowingDirectory){
            currentDirectory = index
            withAnimation(.easeIn(duration: 0.2)) {
                isShowingDirectory.toggle()
            }
        }else if(isShowingDirectory && currentDirectory == index){
            withAnimation(.easeIn(duration: 0.2)) {
                isShowingDirectory.toggle()
            }
        }else{
            currentDirectory = index
        }
    }
    
    func runCode(){
        guard let editor = App.activeEditor else {
            return
        }
        App.runCode(url: editor.url, lang: App.compilerCode)
        DispatchQueue.main.async {
            if(self.panelHeight < 70){
                self.panelHeight = 200
            }
            self.showsPanel = true
            if App.compilerCode < 10 {
                self.currentPanelTab = 2
            }else{
                self.currentPanelTab = 1
            }
            
        }
    }
    
    var body: some View{
        GeometryReader { geometry in
            ZStack{
                VStack(alignment: .leading, spacing: 0){
                    HStack(spacing: 0){
                        if horizontalSizeClass == .regular {
                            VStack(spacing: 0){

                                Group{
                                    Button(action: {self.openSidePanel(index: 0)}) {
                                        ZStack{
                                            Text("Show Explorer").foregroundColor(.clear).font(.system(size: 1))
                                            Image(systemName: "doc.on.doc").font(.system(size: 20, weight: .light)).foregroundColor(Color.init(id: (self.currentDirectory == 0 && isShowingDirectory) ? "activityBar.foreground" : "activityBar.inactiveForeground")).padding(5)
                                        }.frame(maxWidth: .infinity, minHeight: 60.0)
                                    }
                                    .keyboardShortcut("e", modifiers: [.command, .shift])
                                    .contextMenu {

                                        Button(action: {
                                            self.openNewFile()
                                        }) {
                                            Text(NSLocalizedString("New File", comment: ""))
                                            Image(systemName: "doc.badge.plus")
                                        }

                                        Button(action: {
                                            self.openFile()
                                        }) {
                                            Text(NSLocalizedString("Open File", comment: ""))
                                            Image(systemName: "doc")
                                        }

                                        Button(action: {
                                            self.openFolder()
                                        }) {
                                            Text(NSLocalizedString("Open Folder", comment: ""))
                                            Image(systemName: "folder.badge.gear")
                                        }

                                    }

                                    Button(action: {
                                        self.openSidePanel(index: 1)

                                    }) {
                                        ZStack{
                                            Text("Show Search").foregroundColor(.clear).font(.system(size: 1))
                                            Image(systemName: "magnifyingglass").font(.system(size: 20, weight: .light)).foregroundColor(Color.init(id: (self.currentDirectory == 1 && isShowingDirectory) ? "activityBar.foreground" : "activityBar.inactiveForeground")).padding(5)
                                        }.frame(maxWidth: .infinity, minHeight: 60.0)
                                    }
                                    .keyboardShortcut("f", modifiers: [.command, .shift])
                                    
                                    ZStack{
                                        Button(action: {self.openSidePanel(index: 3)}) {
                                            ZStack{
                                                Text("Show Source Control").foregroundColor(.clear).font(.system(size: 1))
                                                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up").font(.system(size: 20, weight: .light)).foregroundColor(Color.init(id: (self.currentDirectory == 3 && isShowingDirectory) ? "activityBar.foreground" : "activityBar.inactiveForeground")).padding(5)
                                            }.frame(maxWidth: .infinity, minHeight: 60.0)
                                        }
                                        .keyboardShortcut("g", modifiers: [.control, .shift])
                                        if !App.gitTracks.isEmpty{
                                            ZStack{
                                                Text("\(App.gitTracks.count)").font(.system(size:12)).foregroundColor(Color.init(id: "statusBar.foreground"))
                                            }.padding(.horizontal, 3).background(Color.init(id: "statusBar.background")).cornerRadius(5).offset(x: 10, y: -10)
                                        }
                                    }
                                    
//                                    Button(action: {
//                                        self.openSidePanel(index: 4)
//                                    }) {
//                                        ZStack{
//                                            Text("Remotes").foregroundColor(.clear).font(.system(size: 1))
//                                            Image(systemName: "rectangle.connected.to.line.below").font(.system(size: 20, weight: .light)).foregroundColor(Color.init(id: (self.currentDirectory == 4 && isShowingDirectory) ? "activityBar.foreground" : "activityBar.inactiveForeground")).padding(5)
//                                        }.frame(maxWidth: .infinity, minHeight: 60.0)
//                                    }
                                    
                                    Button(action: {self.openConsolePanel()}) {
                                        ZStack{
                                            Text("Show Panel").foregroundColor(.clear).font(.system(size: 1))
                                            Image(systemName: "chevron.left.slash.chevron.right").font(.system(size: 20, weight: .light)).foregroundColor(Color.init(id: (self.showsPanel) ? "activityBar.foreground" : "activityBar.inactiveForeground")).padding(5)
                                        }.frame(maxWidth: .infinity, minHeight: 60.0)

                                    }
                                    .keyboardShortcut("j", modifiers: .command)
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                // This flickers for some reason in iPadOS 15
//                                .hoverEffect(.highlight)
                                .frame(minWidth: 0, maxWidth: self.returnBarSize(), minHeight: 0, maxHeight: 60.0)

                                ZStack {
                                    Color.black.opacity(0.001)
                                    Spacer()
                                }.onTapGesture {
                                    App.monacoInstance.executeJavascript(command: "document.getElementById('overlay').focus()")
                                    App.terminalInstance.executeScript("document.getElementById('overlay').focus()")
                                }

                                Button(action: {self.showingSettingsSheet.toggle()}) {
                                    ZStack{
                                        Text("User Settings").foregroundColor(.clear).font(.system(size: 1))
                                        Image(systemName: "slider.horizontal.3").font(.system(size: 20, weight: .light)).foregroundColor(.gray).padding(5)
                                    }.frame(maxWidth: .infinity, minHeight: 60.0)
                                }
                                .keyboardShortcut(",", modifiers: [.command])
                                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
//                                .hoverEffect(.highlight)
                                .frame(minWidth: 0, maxWidth: self.returnBarSize(), minHeight: 0, maxHeight: 60.0)
                            }.frame(minWidth: 0, maxWidth: self.returnBarSize(), minHeight: 0, maxHeight: .infinity).background(Color.init(id: "activityBar.background"))
                        }
                        
                        if isShowingDirectory && horizontalSizeClass == .regular {
                            ZStack(alignment: .topLeading){
                                
                                Group{
                                    if self.currentDirectory == 0 {
                                        explorer(showingNewFileSheet: $showingNewFileSheet, showsDirectoryPicker: $showsDirectoryPicker)
                                    }else if self.currentDirectory == 1 {
                                        search()
                                    }else if self.currentDirectory == 3 {
                                        git()
                                    }else if self.currentDirectory == 4 {
                                        remote()
                                    }
                                }.background(Color.init(id: "sideBar.background"))
                                
                            }.frame(width: 280.0, height: geometry.size.height - 20).background(Color.init(id: "sideBar.background"))
                        }
                            
                        ZStack{
                            VStack(spacing: 0){
                                tabBar(isShowingDirectory: $isShowingDirectory, showingSettingsSheet: $showingSettingsSheet, showSafari: $showSafari, runCode: runCode, openConsolePanel: openConsolePanel)
                                    .frame(height: 40)
                                
                                editorView(showsNewFile: $showingNewFileSheet, showsDirectory: $isShowingDirectory, showsFolderPicker: $showsDirectoryPicker, showsFilePicker: $showsFilePicker, directoryID: $currentDirectory)
                                    .disabled(horizontalSizeClass == .compact && isShowingDirectory)
                                    .sheet(isPresented: $showingNewFileSheet) {
                                        newFileView(targetUrl: App.workSpaceStorage.currentDirectory.url).environmentObject(App)
                                    }
                                
                                if showsPanel{
                                    panelView(showsPanel: self.$showsPanel, panelHeight: self.$panelHeight, isShowingInput: self.$panelShowingInput, showSplitView: $panelShowSplitView, currentTab: $currentPanelTab)
                                }
                            }
                            .edgesIgnoringSafeArea(.bottom)
                            .blur(radius: (horizontalSizeClass == .compact && isShowingDirectory) ? 10 : 0)
                            
                            
                            if isShowingDirectory && horizontalSizeClass == .compact {
                                HStack(spacing: 0){
                                    VStack{
                                        if #available(iOS 15.0, *){
                                            HStack{
                                                Button(action: {
                                                    withAnimation(.easeIn(duration: 0.2)) {
                                                        isShowingDirectory.toggle()
                                                    }
                                                }){
                                                    Image(systemName: "sidebar.left")
                                                        .font(.system(size: 17))
                                                        .foregroundColor(Color.init("T1"))
                                                        .padding(5)
                                                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                        .hoverEffect(.highlight)
                                                        .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20)
                                                        .padding()
                                                }.sheet(isPresented: $showingNewFileSheet) {
                                                    newFileView(targetUrl: App.workSpaceStorage.currentDirectory.url).environmentObject(App)
                                                }
                                                Spacer()
                                                Menu {
                                                    Picker(selection: $currentDirectory, label: Text("Section")){
                                                        ForEach([0,1,3,4], id: \.self){value in
                                                            Label(sections[value]![0], systemImage: sections[value]![1])
                                                        }
                                                    }
                                                }label: {
                                                    Image(systemName: "ellipsis.circle")
                                                        .font(.system(size: 17))
                                                        .foregroundColor(Color.init("T1"))
                                                        .padding(5)
                                                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                        .hoverEffect(.highlight)
                                                        .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20)
                                                        .padding()
                                                }
                                            }
                                            .background(Color.init(id: "sideBar.background").ignoresSafeArea(.container, edges: .top))
                                            .frame(height: 40)
                                            
                                            Group{
                                                if self.currentDirectory == 0 {
                                                    explorer(showingNewFileSheet: $showingNewFileSheet, showsDirectoryPicker: $showsDirectoryPicker)
                                                }else if self.currentDirectory == 1 {
                                                    search()
                                                }else if self.currentDirectory == 3 {
                                                    git()
                                                }
                                            }.background(Color.init(id: "sideBar.background"))
                                        }else{
                                            ZStack(alignment: .topLeading){
                                                Group{
                                                    if self.currentDirectory == 0 {
                                                        explorer(showingNewFileSheet: $showingNewFileSheet, showsDirectoryPicker: $showsDirectoryPicker)
                                                    }else if self.currentDirectory == 1 {
                                                        search()
                                                    }else if self.currentDirectory == 3 {
                                                        git()
                                                    }
                                                }.background(Color.init(id: "sideBar.background"))
                                                
                                                HStack{
                                                    Button(action: {
                                                        withAnimation(.easeIn(duration: 0.2)) {
                                                            isShowingDirectory.toggle()
                                                        }
                                                    }){
                                                        Image(systemName: "sidebar.left")
                                                            .font(.system(size: 17))
                                                            .foregroundColor(Color.init("T1"))
                                                            .padding(5)
                                                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                            .hoverEffect(.highlight)
                                                            .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20)
                                                            .padding()
                                                    }.sheet(isPresented: $showingNewFileSheet) {
                                                        newFileView(targetUrl: App.workSpaceStorage.currentDirectory.url).environmentObject(App)
                                                    }
                                                    Spacer()
                                                    Menu {
                                                        Picker(selection: $currentDirectory, label: Text("Section")){
                                                            ForEach([0,1,3,4], id: \.self){value in
                                                                Label(sections[value]![0], systemImage: sections[value]![1])
                                                            }
                                                        }
                                                    }label: {
                                                        Image(systemName: "ellipsis.circle")
                                                            .font(.system(size: 17))
                                                            .foregroundColor(Color.init("T1"))
                                                            .padding(5)
                                                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                            .hoverEffect(.highlight)
                                                            .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20)
                                                            .padding()
                                                    }
                                                }
                                                .background(Color.init(id: "sideBar.background").ignoresSafeArea(.container, edges: .top))
                                                .frame(height: 40)
                                            }
                                            
                                            
                                            
                                        }
                                        
                                    }
                                    .frame(width: 280.0, height: geometry.size.height - 20).background(Color.init(id: "sideBar.background"))
                                    
                                    ZStack{
                                        Color.black.opacity(0.001)
                                        Spacer()
                                    }.onTapGesture {
                                        withAnimation(.easeIn(duration: 0.2)) {
                                            isShowingDirectory.toggle()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    bottomBar(showChangeLog: showChangeLog, showingNewFileSheet: $showingNewFileSheet, showSafari: $showSafari, showsFilePicker: $showsFilePicker, showsDirectoryPicker: $showsDirectoryPicker, openConsolePanel: openConsolePanel, onDirectoryPickerFinished: {
                        currentDirectory = 0
                        isShowingDirectory = true
                    })
                        .frame(width: geometry.size.width ,height: 20)
                }
                
                HStack(){
                    Spacer()
                    VStack{
                        Spacer()
                        BannerCentreView().padding(.trailing, (self.horizontalSizeClass == .compact ? 40 : 10))
                    }
                }.padding(.bottom, 30).frame(width: geometry.size.width)
                
            }
            .background(Color.init(id: "sideBar.background").edgesIgnoringSafeArea(.all))
            .environmentObject(App).accentColor(Color.init(id: "activityBar.inactiveForeground"))
            .navigationTitle(URL(string: App.workSpaceStorage.currentDirectory.url)?.lastPathComponent ?? "")
            .onReceive(NotificationCenter.default.publisher(for: UIScene.didDisconnectNotification)) { _ in
                UserDefaults.standard.setValue(isShowingDirectory, forKey: "mainView.sideBarEnabled")
                UserDefaults.standard.setValue(currentDirectory, forKey: "mainView.sideBarIndex")
                UserDefaults.standard.setValue(showsPanel, forKey: "mainView.panelEnabled")
                UserDefaults.standard.setValue(currentPanelTab, forKey: "mainView.panelIndex")
                App.saveUserStates()
            }
        }
    }
}
