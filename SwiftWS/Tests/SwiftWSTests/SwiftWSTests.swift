import XCTest
@testable import SwiftWS

final class SwiftWSTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        let expectation = XCTestExpectation(description: "")
        
        let wss = SwiftWS(port: 8888)
        
//        wss.shouldUpgrade = { head in
//            return head.uri.starts(with: "/websocket")
//        }
//        
        wss.onConnection { ws, head in
            if !head.uri.starts(with: "/websocket") {
                ws.close(code: 3000, reason: "wrong url")
                return
            }
            ws.send(head.uri)
            
            ws.onMessage { event in
                print(event.data)
                ws.send("Received: \(event.data)")
            }
            ws.onClose { event in
                print("WS Closed, Reason: \(event.reason)")
            }
        }
        
        wait(for: [expectation], timeout: 120.0)
        
    }
}
