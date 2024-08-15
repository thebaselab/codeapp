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

extension SwiftWS.WebSocket {
    public struct MessageEvent {
        public let data: String
        public let type: String
        public let target: SwiftWS.WebSocket
    }
    
    public struct CloseEvent {
        public let wasClean: Bool
        public let code: Int
        public let reason: String
        public let target: SwiftWS.WebSocket
    }
}

extension SwiftWS {
    public class WebSocket {
        internal var messageStack: [String] = []
        
        internal var onMessageAction: ((WebSocket.MessageEvent) -> Void)?
        internal var onCloseAction: ((WebSocket.CloseEvent) -> Void)?
        
        internal var isClosing: Bool = false
        internal var closeCode: Int = 0
        internal var closeReason: String = ""
        
        public func onMessage(_ action: @escaping ((WebSocket.MessageEvent) -> Void)){
            self.onMessageAction = action
        }
        
        public func onClose(_ action: @escaping ((WebSocket.CloseEvent) -> Void)){
            self.onCloseAction = action
        }
        
        public func send(_ data: String, _ cb: ((NSError?) -> Void)? = nil){
            messageStack.append(data)
        }
        
        public func close(code: Int, reason: String){
            self.closeCode = code
            self.closeReason = reason
            self.isClosing = true
        }
    }
    
    public struct LaunchOptions {
        var port: Int
        
        public init(port: Int){
            self.port = port
        }
    }
}

open class SwiftWS {
    
    public typealias onConnectionActionBlock = ((WebSocket, HTTPRequestHead) -> Void)
    public typealias ShouldUpgradeBlock = ((HTTPRequestHead) -> Bool)
    
    private var queue: DispatchQueue
    
    private var channel: Channel?
    private var launchOptions: LaunchOptions
    private var onConnectionAction: onConnectionActionBlock?
    public var shouldUpgrade: ShouldUpgradeBlock = {_ in true}
    
    public init(port: Int, queue: DispatchQueue = DispatchQueue.global(qos: .utility)){
        self.launchOptions = LaunchOptions(port: port)
        self.queue = queue
        
        queue.async {
            self.startWS()
        }
    }
    
    public func onConnection(_ action: @escaping onConnectionActionBlock){
        self.onConnectionAction = action
    }
    
    public func close(){
        try? channel?.close().wait()
        print("Server closed")
    }
    
    private func startWS(){
        let group = NIOTSEventLoopGroup()
        
        defer {
            try! group.syncShutdownGracefully()
        }

        let upgrader = NIOWebSocketServerUpgrader(
            maxFrameSize: Int(UInt32.max),
            shouldUpgrade: { (channel: Channel, head: HTTPRequestHead) in
                if self.shouldUpgrade(head) {
                    channel.eventLoop.makeSucceededFuture(HTTPHeaders())
                }else {
                    channel.eventLoop.makeSucceededFuture(nil)
                }
            }, upgradePipelineHandler: { (channel: Channel, head: HTTPRequestHead) in
                let ws = WebSocket.init()
                self.onConnectionAction?(ws, head)
                return channel.pipeline.addHandler(WebSocketTimeHandler(ws))
            })

        let bootstrap = NIOTSListenerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                let config: NIOHTTPServerUpgradeConfiguration = (
                    upgraders: [ upgrader ],
                    completionHandler: { _ in}
                )
                return channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: config)
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        do {
            channel = try { () -> Channel in
                return try bootstrap.bind(host: "127.0.0.1", port: launchOptions.port).wait()
            }()
        }catch {
            fputs(error.localizedDescription, stderr)
        }

        guard let localAddress = channel?.localAddress else {
            fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
        }
        fputs("Server started and listening on \(localAddress)", stderr)

        // This will never unblock as we don't close the ServerChannel
        try? channel?.closeFuture.wait()

        fputs("Server closed", stderr)
        fflush(stderr)
    }
}
