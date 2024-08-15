//
//  LSPFrameAdaptor.swift
//  extension
//
//  Created by Ken Chung on 14/08/2024.
//

import Foundation

class LSPFrameAdaptor {
    var onSendToWebSocket: ((String) -> Void)?
    var onWriteToStdin: ((String) -> Void)?
    private var contentLength: Int = 0
    private var buffer: String = ""

    func receiveWebSocket(data: String){
        let message = "Content-Length: \(String(data.utf8.count))\r\n\r\n\(data)"
        onWriteToStdin?(message)
    }

    private func getContentLength(data: String) -> Int? {
        if !data.hasPrefix("Content-Length") { return nil }
        let contentLength = data.split(separator: "\r\n", maxSplits: 1).first
        return Int(contentLength?.split(separator: " ").last ?? "")
    }

    private func removeHeader(data: String) -> String {
        return String(data.split(separator: "\r\n\r\n", maxSplits: 1).last ?? "")
    }
    
    func receiveStdout(data: String){
        if let contentLength = getContentLength(data: data) {
            self.contentLength = contentLength
            buffer = removeHeader(data: data)
        } else {
            buffer += removeHeader(data: data)
        }

        if buffer.utf8.count >= contentLength {
            onSendToWebSocket?(buffer)
            buffer = ""
            contentLength = 0
        }
    }
}
