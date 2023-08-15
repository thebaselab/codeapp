//
//  SimpleWebPreviewExtension.swift
//  Code
//
//  Created by Ken Chung on 2/12/2022.
//

import GCDWebServers

class SimpleWebPreviewExtension: CodeAppExtension {

    private let webServer = GCDWebServer()
    private var port = 8001

    deinit {
        if self.webServer.isRunning {
            self.webServer.stop()
            self.webServer.removeAllHandlers()
        }
    }

    override func onInitialize(app: MainApp, contribution: CodeAppExtension.Contribution) {
        if let url = app.workSpaceStorage.currentDirectory._url {
            self.onWorkSpaceStorageChanged(newUrl: url)
        }

        let toolbarItem = ToolbarItem(
            extenionID: "WEB_PREVIEW",
            icon: "safari",
            onClick: {
                if let activeEditorWithURL =
                    (app.activeEditor as? EditorInstanceWithURL),
                    let baseURL = app.workSpaceStorage.currentDirectory._url,
                    let relativePath = activeEditorWithURL.url.relativePath(
                        from: baseURL)?.replacingOccurrences(of: " ", with: "%20"),
                    let urlToGo = URL(string: "http://localhost:\(self.port)/\(relativePath)")
                {
                    app.safariManager.showSafari(url: urlToGo)
                }
            },
            shouldDisplay: {
                guard self.webServer.isRunning else { return false }
                guard let textEditor = app.activeEditor as? TextEditorInstance else {
                    return false
                }
                return textEditor.url.isFileURL && textEditor.languageIdentifier == "html"
            })
        contribution.toolBar.registerItem(item: toolbarItem)
    }

    override func onWorkSpaceStorageChanged(newUrl: URL) {
        if self.webServer.isRunning {
            self.webServer.stop()
            self.webServer.removeAllHandlers()
        }

        guard newUrl.isFileURL else { return }

        port = 8000
        while port < 8010 && !webServer.isRunning {
            port += 1
            try? startWebServer(url: newUrl, port: port)
        }
    }

    private func startWebServer(url: URL, port: Int) throws {
        webServer.addGETHandler(
            forBasePath: "/", directoryPath: url.path, indexFilename: "index.html",
            cacheAge: 10, allowRangeRequests: true)
        try webServer.start(options: [
            GCDWebServerOption_AutomaticallySuspendInBackground: true,
            GCDWebServerOption_Port: port,
        ])
    }
}
