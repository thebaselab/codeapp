//
//  WASMService.swift
//  Code
//
//  Created by Ken Chung on 14/03/2024.
//

import GCDWebServers

class WASMService {
    static let PORT = 20233
    private let webServer = GCDWebServer()

    init() {
        let basePath = "/"
        let directoryPath = Resources.wasmHTML.deletingLastPathComponent().path + "/"
        webServer.addHandler(
            match: { requestMethod, requestURL, requestHeaders, urlPath, urlQuery in
                if requestMethod != "GET" {
                    return nil
                }
                if !urlPath.hasPrefix(basePath) {
                    return nil
                }
                return GCDWebServerRequest(
                    method: requestMethod, url: requestURL, headers: requestHeaders, path: urlPath,
                    query: urlQuery)
            },
            processBlock: { request in
                let filePath =
                    directoryPath
                    + GCDWebServerNormalizePath(String(request.path.dropFirst(basePath.count)))
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory),
                    !isDirectory.boolValue
                else {
                    return GCDWebServerResponse(
                        statusCode: GCDWebServerClientErrorHTTPStatusCode.httpStatusCode_NotFound
                            .rawValue)
                }
                let response = GCDWebServerFileResponse(
                    file: filePath, byteRange: request.byteRange)
                response?.setValue("bytes", forAdditionalHeader: "Accept-Ranges")
                response?.setValue("same-origin", forAdditionalHeader: "Cross-Origin-Opener-Policy")
                response?.setValue(
                    "require-corp", forAdditionalHeader: "Cross-Origin-Embedder-Policy")
                response?.setValue(
                    "same-origin", forAdditionalHeader: "Cross-Origin-Resource-Policy")
                response?.cacheControlMaxAge = 10
                return response
            })

        try? webServer.start(options: [
            GCDWebServerOption_AutomaticallySuspendInBackground: true,
            GCDWebServerOption_BindToLocalhost: true,
            GCDWebServerOption_Port: WASMService.PORT,
        ])
    }
}
