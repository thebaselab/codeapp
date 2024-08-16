//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//


import NIO
import NIOHTTP1
import NIOWebSocket
import NIOTransportServices
import Network
import Foundation

final class WebSocketTimeHandler: ChannelInboundHandler {
    
    private var ws: SwiftWS.WebSocket
    
    init(_ ws: SwiftWS.WebSocket){
        self.ws = ws
    }
    
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame

    private var awaitingClose: Bool = false

    public func handlerAdded(context: ChannelHandlerContext) {
        self.checkForMessage(context: context)
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)

        switch frame.opcode {
        case .connectionClose:
            ws.onCloseAction?(.init(wasClean: true, code: 0, reason: "Close event received", target: ws))
            self.receivedClose(context: context, frame: frame)
        case .ping:
            self.pong(context: context, frame: frame)
        case .text:
            var data = frame.unmaskedData
            let text = data.readString(length: data.readableBytes) ?? ""
            ws.onMessageAction?(.init(data: text, type: "", target: ws))
        case .binary, .continuation, .pong:
            // We ignore these frames.
            break
        default:
            // Unknown frames are errors.
            ws.onCloseAction?(.init(wasClean: false, code: 0, reason: "Unknown frames errors", target: ws))
            self.closeOnError(context: context)
        }
    }

    public func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    private func checkForMessage(context: ChannelHandlerContext) {
        guard context.channel.isActive else { return }

        // We can't send if we sent a close message.
        guard !self.awaitingClose else { return }

        if ws.isClosing {
            var buffer = context.channel.allocator.buffer(capacity: 2)
            buffer.writeInteger(UInt16(ws.closeCode))
            buffer.writeString(ws.closeReason)
            let closeFrame = WebSocketFrame(fin: true, opcode: .connectionClose, data: buffer)
            _ = context.writeAndFlush(self.wrapOutboundOut(closeFrame))
            awaitingClose = true
            return
        }
        // We can't really check for error here, but it's also not the purpose of the
        // example so let's not worry about it.
        ws.messageStackLock.lock()
        if !ws.messageStack.isEmpty{
            for message in ws.messageStack {
                let buffer = context.channel.allocator.buffer(string: message)
                let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
                context.write(self.wrapOutboundOut(frame))
                    .whenFailure { (_: Error) in
                        context.close(promise: nil)
                    }
            }
            ws.messageStack.removeAll()
            context.flush()
        }
        ws.messageStackLock.unlock()

        context.eventLoop.scheduleTask(in: .milliseconds(100), { self.checkForMessage(context: context) })
    }

    private func receivedClose(context: ChannelHandlerContext, frame: WebSocketFrame) {
        // Handle a received close frame. In websockets, we're just going to send the close
        // frame and then close, unless we already sent our own close frame.
        if awaitingClose {
            // Cool, we started the close and were waiting for the user. We're done.
            context.close(promise: nil)
        } else {
            // This is an unsolicited close. We're going to send a response frame and
            // then, when we've sent it, close up shop. We should send back the close code the remote
            // peer sent us, unless they didn't send one at all.
            var data = frame.unmaskedData
            let closeDataCode = data.readSlice(length: 2) ?? ByteBuffer()
            let closeFrame = WebSocketFrame(fin: true, opcode: .connectionClose, data: closeDataCode)
            _ = context.write(self.wrapOutboundOut(closeFrame)).map { () in
                context.close(promise: nil)
            }
        }
    }

    private func pong(context: ChannelHandlerContext, frame: WebSocketFrame) {
        var frameData = frame.data
        let maskingKey = frame.maskKey

        if let maskingKey = maskingKey {
            frameData.webSocketUnmask(maskingKey)
        }

        let responseFrame = WebSocketFrame(fin: true, opcode: .pong, data: frameData)
        context.write(self.wrapOutboundOut(responseFrame), promise: nil)
    }

    private func closeOnError(context: ChannelHandlerContext) {
        // We have hit an error, we want to close. We do that by sending a close frame and then
        // shutting down the write side of the connection.
        var data = context.channel.allocator.buffer(capacity: 2)
        data.write(webSocketErrorCode: .protocolError)
        let frame = WebSocketFrame(fin: true, opcode: .connectionClose, data: data)
        context.write(self.wrapOutboundOut(frame)).whenComplete { (_: Result<Void, Error>) in
            context.close(mode: .output, promise: nil)
        }
        awaitingClose = true
    }
}
