//
//  TerminalProvider.swift
//  Code
//
//  Created by Ken Chung on 3/5/2022.
//

import Foundation

protocol TerminalServiceProvider {
    // Kill the current process.
    func kill()

    // Set the terminal window size.
    func setWindowsSize(cols: Int, rows: Int)

    // Write to stdin
    func write(data: Data)

    // Set Stdout callback
    // The callback will be called when stdout is being written
    func onStdout(callback: @escaping (Data) -> Void)

    // Set Stderr callback
    // The callback will be called when stderr is being written
    func onStderr(callback: @escaping (Data) -> Void)

    func onDisconnect(callback: @escaping () -> Void)
}
