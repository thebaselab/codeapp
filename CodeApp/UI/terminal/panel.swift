//
//  panel.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI
import ios_system

struct panelView: View{
    
    @EnvironmentObject var App: MainApp
    
    @AppStorage("consoleFontSize") var consoleFontSize: Int = 14
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @Binding var showsPanel: Bool
    @Binding var panelHeight: CGFloat
    @Binding var isShowingInput: Bool
    @Binding var showSplitView: Bool
    
    @Binding var currentTab: Int
    @State var showSheet = false
    
    @State var keyboardHeight: CGFloat = 0.0
    
    var body: some View {
        VStack(spacing: 0){
            HStack(){
                Rectangle().frame(minWidth: 0, maxWidth: .infinity, maxHeight: 1).foregroundColor(Color.init(id: "panel.border"))
            }
            
            HStack(){
                if currentTab == -1 {
                    Text("PROBLEMS").foregroundColor(Color.init(id: "panelTitle.activeForeground")).font(.system(size: 12, weight: .light)).padding(.leading)
                }else{
                    Text("PROBLEMS").foregroundColor(Color.init(id: "panelTitle.inactiveForeground")).font(.system(size: 12, weight: .light)).padding(.leading).onTapGesture {
                        self.currentTab = -1
                    }
                }
                
                Circle()
                    .fill(Color.init(id: "panel.border"))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Text("\(App.problems.values.map{$0.count}.reduce(0, +))").foregroundColor(Color.init(id: "panelTitle.activeForeground")).font(.system(size: 10))
                    )
                
                if currentTab == 0 || (showSplitView && (currentTab == 0 || currentTab == 1)){
                    Text(NSLocalizedString("INPUT", comment: "")).foregroundColor(Color.init(id: "panelTitle.activeForeground")).font(.system(size: 12, weight: .light)).padding(.leading)
                }else{
                    Text(NSLocalizedString("INPUT", comment: "")).foregroundColor(Color.init(id: "panelTitle.inactiveForeground")).font(.system(size: 12, weight: .light)).padding(.leading).onTapGesture {
                        self.currentTab = 0
                    }
                }
                
                if currentTab == 1 || (showSplitView && (currentTab == 0 || currentTab == 1)){
                    Text(NSLocalizedString("OUTPUT", comment: "")).foregroundColor(Color.init(id: "panelTitle.activeForeground")).font(.system(size: 12, weight: .light)).padding(.leading)
                }else{
                    Text(NSLocalizedString("OUTPUT", comment: "")).foregroundColor(Color.init(id: "panelTitle.inactiveForeground")).font(.system(size: 12, weight: .light)).padding(.leading).onTapGesture {
                        self.currentTab = 1
                    }
                }
                
                if currentTab == 2 {
                    Text(NSLocalizedString("TERMINAL", comment: "")).foregroundColor(Color.init(id: "panelTitle.activeForeground")).font(.system(size: 12, weight: .light)).padding(.leading)
                }else{
                    Text(NSLocalizedString("TERMINAL", comment: "")).foregroundColor(Color.init(id: "panelTitle.inactiveForeground")).font(.system(size: 12, weight: .light)).padding(.leading).onTapGesture {
                        self.currentTab = 2
                    }
                }
                
//                Text("SSH").foregroundColor(currentTab == 3 ? Color.init(id: "panelTitle.activeForeground") : Color.init(id: "panelTitle.inactiveForeground")).font(.system(size: 12, weight: .light)).padding(.leading)
//                    .onTapGesture {
//                        self.currentTab = 3
//                    }
                
                Spacer()
                
                Group {
                    if currentTab == 1 || currentTab == 0{
                        languageSelector()
                    }
                    
                    if horizontalSizeClass != .compact && (currentTab == 1 || currentTab == 0) {
                        Button(action: {
                            showSplitView.toggle()
                        }) {
                            Image(systemName: "square.split.2x1").font(.system(size: 14, weight: .light)).foregroundColor(Color.init(id: "panelTitle.activeForeground")).padding(3)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .hoverEffect(.highlight)
                        .frame(minWidth: 0, maxWidth: 8, minHeight: 0, maxHeight: 8)
                        .padding(.trailing)
                    }
                    
                    if (showSplitView && (currentTab == 0 || currentTab == 1)) || currentTab == 1{
                        Button(action: {
                            let pasteboard = UIPasteboard.general
                            pasteboard.string = App.compileManager.consoleContent
                        }) {
                            Image(systemName: "doc.on.doc").font(.system(size: 12, weight: .light)).foregroundColor(Color.init(id: "panelTitle.activeForeground")).padding(3)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .hoverEffect(.highlight)
                        .frame(minWidth: 0, maxWidth: 8, minHeight: 0, maxHeight: 8)
                        .padding(.trailing)
                    }
                    
                    if currentTab == 2 {
                        Image(systemName: "stop").font(.system(size: 12, weight: .light)).foregroundColor(Color.init(id: "panelTitle.activeForeground")).padding(3)
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .hoverEffect(.highlight)
                            .frame(minWidth: 0, maxWidth: 8, minHeight: 0, maxHeight: 8)
                            .padding(.trailing)
                            .highPriorityGesture(TapGesture().onEnded{
                                if nodeUUID != nil {
                                    let notificationName = CFNotificationName("com.thebaselab.code.node.stop" as CFString)
                                    let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
                                    CFNotificationCenterPostNotification(notificationCenter, notificationName, nil, nil, false)
                                }
                                ios_kill()
                            })
                    }
                    
                    if currentTab != -1 {
                        Image(systemName: "trash").font(.system(size: 12, weight: .light)).foregroundColor(Color.init(id: "panelTitle.activeForeground")).padding(3)
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .hoverEffect(.highlight)
                            .frame(minWidth: 0, maxWidth: 8, minHeight: 0, maxHeight: 8)
                            .padding(.trailing)
                            .highPriorityGesture(TapGesture().onEnded{
                                print("currentTab: \(currentTab)")
                                if showSplitView || currentTab == 1{
                                    App.compileManager.consoleContent = ""
                                }else if currentTab == 2 {
                                    guard let prompt = App.terminalInstance.executor?.prompt else{
                                        return
                                    }
                                    App.terminalInstance.executeScript(#"term.write('\033c"# + "\(prompt)' + localEcho._input)")
                                }else if currentTab == 0{
                                    App.compileManager.stdin = ""
                                }
                            })
                    }
                }
                
            }.frame(height: 14).padding(.top, 5).padding(.bottom, 5)
            
            HStack(){
                if (showSplitView && (currentTab == 0 || currentTab == 1)) && horizontalSizeClass != .compact{
                    ZStack{
                        if App.compileManager.stdin.isEmpty {
                            VStack(alignment: .leading){
                                HStack{
                                    Text("Program input..")
                                        .font(.custom("Menlo", size: CGFloat(consoleFontSize)))
                                        .foregroundColor(.gray)
                                        .padding(.leading, 15)
                                        .padding(.top, 8)
                                    Spacer()
                                }
                                
                                Spacer()
                            }
                            
                        }
                        TextEditor(text: $App.compileManager.stdin).padding(.leading, 10)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.custom("Menlo", size: CGFloat(consoleFontSize)))
                    }
                    Divider()
                    ScrollView(){
                        HStack{
                            Text(App.compileManager.consoleContent).foregroundColor(Color.init("T1")).font(.custom("Menlo", size: CGFloat(consoleFontSize))).frame(maxHeight: .infinity).padding(.leading)
                            Spacer()
                        }
                    }.frame(maxWidth: .infinity)
                }else{
                    switch currentTab{
                    case -1:
                        problemsView()
                    case 0:
                        ZStack(alignment: .leading){
                            
                            if App.compileManager.stdin.isEmpty {
                                VStack{
                                    Text("Program input..")
                                        .font(.custom("Menlo", size: CGFloat(consoleFontSize)))
                                        .foregroundColor(.gray)
                                        .padding(.leading, 15)
                                        .padding(.top, 8)
                                    Spacer()
                                }
                                
                            }
                            
                            TextEditor(text: $App.compileManager.stdin).padding(.leading, 10)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .font(.custom("Menlo", size: CGFloat(consoleFontSize)))
                        }
                        
                    case 1:
                        ScrollView(){
                            HStack{
                                Text(App.compileManager.consoleContent).foregroundColor(Color.init("T1")).font(.custom("Menlo", size: CGFloat(consoleFontSize))).frame(maxHeight: .infinity).padding(.leading)
                                Spacer()
                            }
                        }.frame(maxWidth: .infinity)
                    case 2:
                        if let wv = App.terminalInstance.webView {
                            ZStack{
                                Button("Clear Console"){
                                    App.terminalInstance.reset()
                                }.keyboardShortcut("k", modifiers: [.command])
                                
                                Button("Kill Process"){
                                    if let state = App.terminalInstance.executor?.state, state == .interactive {
                                        App.terminalInstance.executor?.sendInput(input: "\u{3}")
                                    }else {
                                        if nodeUUID != nil {
                                            let notificationName = CFNotificationName("com.thebaselab.code.node.stop" as CFString)
                                            let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
                                            CFNotificationCenterPostNotification(notificationCenter, notificationName, nil, nil, false)
                                        }
                                        App.terminalInstance.clearLine()
                                        App.terminalInstance.executor?.kill()
                                    }
                                    
                                }
                                .keyboardShortcut("c", modifiers: [.control])
                                
                                ViewRepresentable(wv)
                                    .onTapGesture {
                                        App.monacoInstance.executeJavascript(command: "document.getElementById('overlay').focus()")
                                    }
                                    .onAppear(perform: {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
                                            App.terminalInstance.executeScript("fitAddon.fit()")
                                        }
                                    })
                            }
                            .foregroundColor(.clear)
                            .font(.system(size: 1))
                        }
                    default:
                        Spacer()
                    }
                }
                
            }
            
            Spacer()
        }.frame(height: self.panelHeight).background(Color.init(id: "editor.background"))
        .gesture(
            DragGesture()
                .onChanged{value in
                    if (self.panelHeight + (value.translation.height) * -1) < 40 {
                        self.showsPanel = false
                    }
                    let window = UIApplication.shared.windows[0]
                    let topPadding = window.safeAreaInsets.top
                    let bottomPadding = window.safeAreaInsets.bottom
                    if (self.panelHeight + (value.translation.height) * -1) < (UIScreen.main.bounds.height - (bottomPadding == 0 ? 60 : 0) - topPadding - bottomPadding - keyboardHeight) {
                        self.panelHeight = self.panelHeight + (value.translation.height) * -1
                    }else{
                        self.panelHeight = UIScreen.main.bounds.height - (bottomPadding == 0 ? 60 : 0) - topPadding - bottomPadding - keyboardHeight
                    }
                }
        )
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)){ _ in
            let window = UIApplication.shared.windows[0]
            let topPadding = window.safeAreaInsets.top
            let bottomPadding = window.safeAreaInsets.bottom
            if self.panelHeight > (UIScreen.main.bounds.height - (bottomPadding == 0 ? 60 : 0) - topPadding - bottomPadding - keyboardHeight) {
                self.panelHeight = UIScreen.main.bounds.height - (bottomPadding == 0 ? 60 : 0) - topPadding - bottomPadding - keyboardHeight
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification), perform: { notification in
            if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                let keyboardHeight = keyboardSize.height
                let window = UIApplication.shared.windows[0]
                let topPadding = window.safeAreaInsets.top
                let bottomPadding = window.safeAreaInsets.bottom
                if self.panelHeight > (UIScreen.main.bounds.height - (bottomPadding == 0 ? 60 : 0) - topPadding - bottomPadding - keyboardHeight) {
                    DispatchQueue.main.async {
                        self.panelHeight = UIScreen.main.bounds.height - (bottomPadding == 0 ? 60 : 0) - topPadding - bottomPadding - keyboardHeight
                    }
                }
            }
        })
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidChangeFrameNotification), perform: { notification in
            if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                keyboardHeight = keyboardSize.height
            }
        })
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification), perform: { _ in
            self.keyboardHeight = 0.0
        })
        .onChange(of: consoleFontSize){value in
            App.terminalInstance.setFontSize(size: value)
        }
    }
}
