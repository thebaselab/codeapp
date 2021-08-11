//
//  remote.swift
//  remote
//
//  Created by Ken Chung on 8/8/2021.
//

import SwiftUI
import FilesProvider
import LocalAuthentication

struct remoteBadge: View {
    
    enum remoteType: String, CaseIterable, Identifiable{
        case ftp
        case ftps
        var id: String { self.rawValue }
    }
    
    @State var badgeType: remoteType
    
    init(type: remoteType){
        self.badgeType = type
    }
    
    var body: some View {
        Text(badgeType.rawValue.uppercased())
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .foregroundColor(Color.gray)
        .padding(2)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.gray, lineWidth: 1)
        )
    }
}

struct serverCell: View {
    
    @EnvironmentObject var App: MainApp
    @State var url: URL
    @State var showsPrompt = false
    
    var body: some View {
        HStack{
            Image(systemName: "server.rack")
                .foregroundColor(.gray)
            Text(url.host ?? "")
            Spacer()
            if App.workSpaceStorage.currentDirectory.url == url.absoluteString {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10)
            }
            if let scheme = remoteBadge.remoteType.init(rawValue: url.scheme!){
                remoteBadge(type: scheme)
            }
            
        }.onTapGesture {
            showsPrompt = true
//            let context = LAContext()
//            context.localizedCancelTitle = "Enter Username/Password"
//            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authenticate to \(url.host ?? "server")"){ success, error in
//                if success {
//                    DispatchQueue.main.async {
////                                let cred = URLCredential(user: username, password: password, persistence: .forSession)
////                                App.workSpaceStorage.connectToServer(host: url, credentials: cred){ error in
////                                    if let error = error {
////                                        App.notificationManager.showErrorMessage(error.localizedDescription)
////                                        return
////                                    }else{
////
////                                    }
////                                }
//                    }
//                }else {
//                    // Fallback
//                }
//            }
        }.sheet(isPresented: $showsPrompt){
            ftpAuthView{ username, password in
                let cred = URLCredential(user: username, password: password, persistence: .forSession)
                App.workSpaceStorage.connectToServer(host: url, credentials: cred){ error in
                    if let error = error {
                        App.notificationManager.showErrorMessage(error.localizedDescription)
                    }
                    showsPrompt = false
                }
            }
        }
    }
}

struct remoteServers: View {
    
    @EnvironmentObject var App: MainApp
    @State var servers: [URL]
    
    var body: some View {
        Section(header: Text("Remotes")){
            ForEach(servers, id: \.self){ url in
                serverCell(url: url)
                    .contextMenu{
                        Button {
                            if var hosts = UserDefaults.standard.stringArray(forKey: "remote.hosts"){
                                hosts.removeAll(where: {$0 == url.absoluteString})
                                servers = hosts.compactMap{URL(string: $0)}
                                UserDefaults.standard.set(hosts, forKey: "remote.hosts")
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }
}

struct remote: View {
    
    @EnvironmentObject var App: MainApp
    
    @State var address: String = ""
    @State var password: String = ""
    @State var port: String = "21"
    @State var save: Bool = false
    @State var saveAddress: Bool = true
    @State var username: String = ""
    @State var serverType: remoteBadge.remoteType = .ftp
    @State var servers: [URL]
    
    init(){
        if let hosts = UserDefaults.standard.stringArray(forKey: "remote.hosts"){
            servers = hosts.compactMap{URL(string: $0)}
        }else {
            servers = []
        }
    }
    
    var body: some View {
        List{
            remoteServers(servers: servers)
            
            Section(header: Text("New remote")){
                Group{
                    HStack{
                        Image(systemName: "rectangle.connected.to.line.below")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                        Picker("Protocol", selection: $serverType) {
                            ForEach(remoteBadge.remoteType.allCases) { type in
                                Text(type.rawValue.uppercased())
                            }
                        }.pickerStyle(MenuPickerStyle())
                        Spacer()
                    }.frame(minHeight: 20)
                    
                    HStack{
                        Image(systemName: "link")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                        TextField("Address", text: $address, onCommit: {
                        })
                            .autocapitalization(.none)
                    }
                    
                    HStack{
                        Image(systemName: "network")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                        TextField("Port", text: $port, onCommit: {
                        })
                        
                    }
                    
                    HStack{
                        Image(systemName: "person")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                        TextField("Username", text: $username, onCommit: {
                        })
                            .autocapitalization(.none)
                    }
                    
                    HStack{
                        Image(systemName: "key")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                        SecureField("Password", text: $password, onCommit: {
                        })
                    }
                }
                .padding(7)
                .background(Color.init(id: "input.background"))
                .cornerRadius(15)
                
                Toggle("Remember address", isOn: $saveAddress)
//                Toggle("Remember password", isOn: $save)
                
                HStack(){
                    Spacer()
                    Text("Connect").font(.system(size: 14, weight: .light)).lineLimit(1)
                    Spacer()
                }.onTapGesture{
                    
                    guard !address.isEmpty else {
                        App.notificationManager.showErrorMessage("Address cannot be empty.")
                        return
                    }
                    
                    guard !username.isEmpty else {
                        App.notificationManager.showErrorMessage("Password cannot be empty.")
                        return
                    }
                    
                    guard let url = URL(string: serverType.rawValue.lowercased() + "://" + address + ":\(port)") else {
                        App.notificationManager.showErrorMessage("Invalid address.")
                        return
                    }
                    
                    let cred = URLCredential(user: username, password: password, persistence: .forSession)
                    App.workSpaceStorage.connectToServer(host: url, credentials: cred){ error in
                        if let error = error {
                            App.notificationManager.showErrorMessage(error.localizedDescription)
                            return
                        }else{
                            guard saveAddress else {
                                return
                            }
                            DispatchQueue.main.async {
                                if var hosts = UserDefaults.standard.stringArray(forKey: "remote.hosts"){
                                    hosts.append(url.absoluteString)
                                    servers = hosts.compactMap{URL(string: $0)}
                                    UserDefaults.standard.set(hosts, forKey: "remote.hosts")
                                }else {
                                    servers = [url]
                                    UserDefaults.standard.set([url.absoluteString], forKey: "remote.hosts")
                                }
                                App.notificationManager.showInformationMessage("Connected successfully.")
                            }
                        }
                    }
                    
                }
                .foregroundColor(Color.init("T1"))
                .padding(4)
                .background(Color.init(id: "button.background"))
                .cornerRadius(10.0)
            }
        }.listStyle(SidebarListStyle())
        
        
    }
}
