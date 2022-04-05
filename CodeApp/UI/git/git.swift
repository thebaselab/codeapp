//
//  git.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import StoreKit
import SwiftUI

struct git: View {

    @State var gitURL: String = ""
    @EnvironmentObject var App: MainApp
    @AppStorage("accentColor") var accentColor: String = "blue"
    @AppStorage("user_name") var username: String = ""
    @AppStorage("user_email") var email: String = ""
    @State var showsIdentitySheet: Bool = false

    func humanReadableByteCount(bytes: Int) -> String {
        if bytes < 1000 { return "\(bytes) B" }
        let exp = Int(log2(Double(bytes)) / log2(1000.0))
        let unit = ["KB", "MB", "GB", "TB", "PB", "EB"][exp - 1]
        let number = Double(bytes) / pow(1000, Double(exp))
        return String(format: "%.1f %@", number, unit)
    }

    var body: some View {
        List {
            if App.gitTracks.count > 0 || App.branch != "" {
                Section(
                    header:
                        Text(NSLocalizedString("Source Control", comment: ""))
                        .foregroundColor(Color.init("BW"))
                ) {

                    ZStack(alignment: .leading) {
                        if App.commitMessage.isEmpty {
                            Text("Message (⌘Enter to commit)").font(.system(size: 14))
                                .foregroundColor(.gray).padding(.leading, 3)
                        }
                        TextEditor(text: $App.commitMessage)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .frame(minHeight: 35)
                    .padding(.horizontal, 7).padding(.top, 1)
                    .background(Color.init(id: "input.background"))
                    .cornerRadius(15)

                    HStack {
                        if App.indexedResources.isEmpty {
                            Text("There are no staged changes.").foregroundColor(.gray).font(
                                .system(size: 12, weight: .light))
                        } else {
                            Text(
                                "Commit \(App.indexedResources.count) file\(App.indexedResources.count > 1 ? "s" : "") on '\(App.branch)'..."
                            ).foregroundColor(.gray).font(.system(size: 12, weight: .light))
                        }

                        Spacer()
                        Button(action: {
                            if let isSigned = App.gitServiceProvider?.isSigned(), !isSigned {
                                showsIdentitySheet.toggle()
                            } else if App.gitTracks.isEmpty {
                                App.notificationManager.showWarningMessage(
                                    "There are no staged changes")
                            } else if App.commitMessage.isEmpty {
                                App.notificationManager.showWarningMessage(
                                    "Commit message cannot be empty")
                            } else {
                                App.gitServiceProvider?.commit(
                                    message: App.commitMessage,
                                    error: {
                                        App.notificationManager.showErrorMessage(
                                            $0.localizedDescription)
                                    }
                                ) {
                                    App.git_status()
                                    DispatchQueue.main.async {
                                        App.commitMessage = ""
                                        App.monacoInstance.invalidateDecorations()
                                    }
                                    App.notificationManager.showInformationMessage(
                                        "Commit succeeded")
                                }
                            }
                        }) {
                            Image(systemName: "checkmark.circle")
                        }
                        .buttonStyle(NoAnim())
                        .keyboardShortcut(.return, modifiers: [.command])
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .hoverEffect(.highlight)
                        .font(.system(size: 16))
                        .foregroundColor(Color.init(id: "activityBar.foreground"))

                        Menu {
                            Section {
                                //                                Button(action: {App.pullRepository()}){
                                //                                    Label("Pull", systemImage: "square.and.arrow.down")
                                //                                }
                                Button(action: {
                                    App.notificationManager.showInformationMessage(
                                        "Pushing to remote")
                                    App.gitServiceProvider?.push(error: {
                                        App.notificationManager.showErrorMessage(
                                            $0.localizedDescription)
                                    }) {
                                        App.notificationManager.showInformationMessage(
                                            "Push succeeded")
                                        App.git_status()

                                        DispatchQueue.main.async {
                                            if let scene = UIApplication.shared.connectedScenes
                                                .first(where: {
                                                    $0.activationState == .foregroundActive
                                                }) as? UIWindowScene
                                            {
                                                SKStoreReviewController.requestReview(in: scene)
                                            }
                                        }

                                    }
                                }) {
                                    Label("Push", systemImage: "square.and.arrow.up")
                                }
                                //                                Button(action: {App.syncRepository()}){
                                //                                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                                //                                }
                                Button(action: {
                                    App.notificationManager.showInformationMessage(
                                        "Fetching from origin")
                                    App.gitServiceProvider?.fetch(error: {
                                        App.notificationManager.showErrorMessage(
                                            $0.localizedDescription)
                                    }) {
                                        App.notificationManager.showInformationMessage(
                                            "Fetch succeeded")
                                        App.git_status()
                                    }
                                }) {
                                    Label("Fetch", systemImage: "square.and.arrow.down")
                                }
                            }

                            Section {
                                Button(action: {
                                    let path = App.workingResources.keys.map {
                                        $0.absoluteString.removingPercentEncoding!
                                    }
                                    guard path.count > 0 else {
                                        return
                                    }
                                    do {
                                        try App.gitServiceProvider?.stage(paths: path)
                                        App.git_status()
                                    } catch {
                                        App.notificationManager.showErrorMessage(
                                            error.localizedDescription)
                                    }
                                }) {
                                    Label("Stage All Changes", systemImage: "plus.circle")
                                }
                                //                                Button(action: {}){
                                //                                    Label(NSLocalizedString("Commit Staged", comment: ""), systemImage: "square.and.arrow.down")
                                //                                }
                                //                                Button(action: {}){
                                //                                    Label(NSLocalizedString("Commit All", comment: ""), systemImage: "square.and.arrow.up")
                                //                                }
                                //                                Button(action: {}){
                                //                                    Label(NSLocalizedString("Revert Last Commit", comment: ""), systemImage: "square.and.arrow.up")
                                //                                }
                            }
                            //                            Menu{
                            //
                            //                            }label: {
                            //                                Label("Commit...", systemImage: "ellipsis")
                            //                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .hoverEffect(.highlight)
                                .font(.system(size: 16))
                                .foregroundColor(Color.init(id: "activityBar.foreground"))
                        }

                    }

                }

                if !App.indexedResources.isEmpty {
                    Section(
                        header:
                            Text(NSLocalizedString("Staged Changes", comment: ""))
                            .foregroundColor(Color.init("BW"))
                    ) {
                        ForEach(Array(App.indexedResources.keys), id: \.self) { value in
                            GitCell(itemUrl: value, isIndex: true)
                                .frame(height: 16)
                        }
                    }
                }

                Section(
                    header:
                        Text(NSLocalizedString("Changes", comment: ""))
                        .foregroundColor(Color.init("BW"))
                ) {
                    if App.workingResources.isEmpty {
                        Text("No changes are made in the working directory.").foregroundColor(.gray)
                            .font(.system(size: 12, weight: .light))
                    }
                    ForEach(Array(App.workingResources.keys), id: \.self) { value in
                        GitCell(itemUrl: value, isIndex: false)
                            .frame(height: 16)
                    }
                }

                //                Section(header:
                //                            Text(NSLocalizedString("Timeline", comment: ""))
                //                            .foregroundColor(Color.init("BW"))
                //                ){
                //                    if App.commits.isEmpty{
                //                        Text("The Git repository is empty.").foregroundColor(.gray).font(.system(size: 12, weight: .light))
                //                    }
                //                    ForEach(App.commits.indices.reversed(), id: \.self){index in
                //                        HStack{
                //                            ZStack{
                //                                if index != 0{
                //                                    Rectangle().fill(Color.gray).frame(maxWidth: 1, maxHeight: .infinity)
                //                                }
                //                                VStack{
                //                                    ZStack{
                //                                        Circle().fill(Color.white).frame(width: 8, height: 8)
                //                                        Circle().stroke(Color.gray, lineWidth: 1).frame(width: 8, height: 8)
                //                                    }.padding(.top, 3)
                //                                    Spacer()
                //                                }
                //                            }
                //                            VStack(alignment: .leading){
                //                                Text("\(App.commits[index].author.date)").font(.system(size: 12)).foregroundColor(.gray).padding(.bottom, 3)
                //                                Text("\(App.commits[index].message)").font(.system(size: 12)).fontWeight(.semibold).foregroundColor(Color.init("T1"))
                //                                Text("\(App.commits[index].author.name)").font(.system(size: 12)).foregroundColor(.gray).padding(.bottom, 30)
                //
                //                            }
                //                            Spacer()
                //                        }.listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                //                    }
                //                }
            } else {
                Section(
                    header:
                        Text(NSLocalizedString("Source Control", comment: ""))
                        .foregroundColor(Color.init("BW"))
                ) {
                    Text("The folder currently opened doesn't have a git repository.")
                        .foregroundColor(.gray).font(.system(size: 12, weight: .light)).lineLimit(2)

                    HStack {
                        Spacer()
                        Text("Initialize Repository").foregroundColor(.white).font(
                            .system(size: 14, weight: .light)
                        ).lineLimit(1)
                        Spacer()
                    }.onTapGesture {
                        if username.isEmpty || !email.contains("@") {
                            showsIdentitySheet.toggle()
                        } else {
                            App.gitServiceProvider?.initialize(error: { err in
                                DispatchQueue.main.async {
                                    App.notificationManager.showErrorMessage(
                                        err.localizedDescription)
                                }
                            }) {
                                DispatchQueue.main.async {
                                    App.notificationManager.showInformationMessage(
                                        "Repository initialized")
                                }
                                App.git_status()
                            }
                        }
                    }.foregroundColor(Color.init("T1")).padding(4).background(
                        Color.init(id: "button.background")
                    ).cornerRadius(10.0)
                }

                Section(
                    header:
                        HStack {
                            Text(NSLocalizedString("Clone Repository", comment: ""))
                                .foregroundColor(Color.init("BW"))
                        }

                ) {
                    SearchBar(
                        text: $App.searchManager.searchTerm,
                        searchAction: { App.searchManager.search() }, placeholder: "GitHub",
                        cornerRadius: 15)
                    ForEach(App.searchManager.searchResultItems, id: \.html_url) { item in
                        VStack(alignment: .leading) {
                            HStack {
                                RemoteImage(url: item.owner.avatar_url).frame(width: 20, height: 20)
                                    .cornerRadius(5)
                                Text(item.owner.login).font(.system(size: 12)).foregroundColor(
                                    Color.init("T1"))
                            }

                            Text(item.name).font(.system(size: 14)).fontWeight(.semibold)
                                .foregroundColor(Color.init("T1"))
                            if item.description != nil {
                                Text(item.description!).font(.system(size: 14)).foregroundColor(
                                    Color.init("T1"))
                            }
                            HStack {
                                Image(systemName: "star").font(.system(size: 12)).foregroundColor(
                                    .gray)
                                Text("\(item.stargazers_count)").font(.system(size: 12))
                                    .foregroundColor(.gray)
                                if item.language != nil {
                                    Text(
                                        "\(item.language ?? "")  • \(humanReadableByteCount(bytes: item.size*1024))"
                                    ).font(.system(size: 12)).foregroundColor(.gray)
                                } else {
                                    Text("\(humanReadableByteCount(bytes: item.size*1024))").font(
                                        .system(size: 12)
                                    ).foregroundColor(.gray)
                                }
                                Spacer()
                                Text("Clone").foregroundColor(.white).lineLimit(1).font(
                                    .system(size: 12)
                                ).padding(.leading, 8).padding(.trailing, 8).padding(.top, 4)
                                    .padding(.bottom, 4).background(Color.init(accentColor))
                                    .cornerRadius(10).onTapGesture {

                                        do {
                                            let repo = item.name
                                            guard
                                                let dirURL = URL(
                                                    string: App.workSpaceStorage.currentDirectory
                                                        .url)?.appendingPathComponent(
                                                        repo, isDirectory: true)
                                            else {
                                                return
                                            }
                                            try FileManager.default.createDirectory(
                                                atPath: dirURL.path,
                                                withIntermediateDirectories: true, attributes: nil)

                                            guard let gitURL = URL(string: item.clone_url) else {
                                                App.notificationManager.showErrorMessage(
                                                    "Invalid URL")
                                                return
                                            }
                                            let progress = Progress(totalUnitCount: 100)
                                            App.notificationManager.postProgressNotification(
                                                title: "Cloning into \(repo)", progress: progress)

                                            App.gitServiceProvider?.clone(
                                                from: gitURL, to: dirURL, progress: progress,
                                                error: {
                                                    App.notificationManager.showErrorMessage(
                                                        "Clone error: \($0.localizedDescription)")
                                                }
                                            ) {
                                                App.reloadDirectory()
                                                App.notificationManager.postActionNotification(
                                                    title: "Clone succeeded", level: .success,
                                                    primary: { App.loadFolder(url: dirURL) },
                                                    primaryTitle: "Open Folder", source: repo)
                                            }
                                        } catch {
                                            App.notificationManager.showErrorMessage(
                                                "Clone error: \(error.localizedDescription)")
                                        }
                                    }
                            }.padding(.top, 5)
                        }
                    }.listRowBackground(Color.init(id: "sideBar.background"))

                    if App.searchManager.errorMessage != "" {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text(App.searchManager.errorMessage).font(
                                .system(size: 12, weight: .light))
                        }.foregroundColor(.gray)

                    }

                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                        TextField(
                            "URL (HTTPS)", text: $gitURL,
                            onCommit: {
                                do {
                                    guard let gitURL = URL(string: self.gitURL) else {
                                        App.notificationManager.showErrorMessage("Invalid URL")
                                        return
                                    }

                                    //                                if !gitURL.hasSuffix(".git"){
                                    //                                    gitURL += ".git"
                                    //                                }

                                    let repo = gitURL.deletingPathExtension().lastPathComponent
                                    guard
                                        let dirURL = URL(
                                            string: App.workSpaceStorage.currentDirectory.url)?
                                            .appendingPathComponent(repo, isDirectory: true)
                                    else {
                                        return
                                    }
                                    try FileManager.default.createDirectory(
                                        atPath: dirURL.path, withIntermediateDirectories: true,
                                        attributes: nil)

                                    let progress = Progress(totalUnitCount: 100)
                                    App.notificationManager.postProgressNotification(
                                        title: "Cloning into \(gitURL.absoluteString)",
                                        progress: progress)

                                    App.gitServiceProvider?.clone(
                                        from: gitURL, to: dirURL, progress: progress,
                                        error: {
                                            App.notificationManager.showErrorMessage(
                                                "Clone error: \($0.localizedDescription)")
                                        }
                                    ) {
                                        self.gitURL = ""
                                        App.notificationManager.postActionNotification(
                                            title: "Clone succeeded", level: .success,
                                            primary: {
                                                App.loadFolder(url: dirURL)
                                            }, primaryTitle: "Open Folder", source: repo)
                                    }
                                } catch {
                                    App.notificationManager.showErrorMessage(
                                        "Clone error: \(error.localizedDescription)")
                                }
                            }
                        )
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        Spacer()

                    }.padding(7)
                        .background(Color.init(id: "input.background"))
                        .cornerRadius(15)

                    Text("Example: https://github.com/thebaselab/codeapp.git").foregroundColor(
                        .gray
                    ).font(.system(size: 12, weight: .light)).lineLimit(2)

                }
            }

        }
        .environment(\.defaultMinListRowHeight, 10)
        .listStyle(SidebarListStyle())
        .sheet(isPresented: $showsIdentitySheet) {
            NavigationView {
                name_email()
            }
        }

    }
}
