//
//  OutputListener.swift
//  extension
//
//  Created by Ken Chung on 02/07/2024.
//

import Foundation

class OutputListener {
    private let inputPipe = Pipe()
    private let outputPipe = Pipe()
    private let inputErrorPipe = Pipe()
    private let outputErrorPipe = Pipe()
    private let stdinPipe = Pipe()
    private let stdoutFileDescriptor = FileHandle.standardOutput.fileDescriptor
    private let stderrFileDescriptor = FileHandle.standardError.fileDescriptor
    private let stdinFileDescriptor = FileHandle.standardInput.fileDescriptor
    private let coordinator = NSFileCoordinator(filePresenter: nil)
    
    public var onStdout: ((String) -> Void)? = nil
    
    init() {
        // Set up a read handler which fires when data is written to our inputPipe
        inputPipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in            
            guard let strongSelf = self else { return }
            let availableData = fileHandle.availableData
            if let str = String(data: availableData, encoding: String.Encoding.utf8) {
                strongSelf.onStdout?(str)
            }
            // Write input back to stdout
            strongSelf.outputPipe.fileHandleForWriting.write(availableData)
        }
        
        inputErrorPipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            guard let strongSelf = self else { return }
            let availableData = fileHandle.availableData
            if let str = String(data: availableData, encoding: String.Encoding.utf8) {
                strongSelf.onStdout?(str)
            }
            // Write input back to stdout
            strongSelf.outputErrorPipe.fileHandleForWriting.write(availableData)
        }
    }
    
    deinit {
        NSLog("OutputListener deinit")
    }
    
    public func write(text: String){
        if let data = text.data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(data)
        }
    }
    
    /// Sets up the "tee" of piped output, intercepting stdout then passing it through.
    public func openConsolePipe() {
        // Copy STDOUT file descriptor to outputPipe for writing strings back to STDOUT
        dup2(stdoutFileDescriptor, outputPipe.fileHandleForWriting.fileDescriptor)
        dup2(stderrFileDescriptor, outputErrorPipe.fileHandleForWriting.fileDescriptor)
        
        // Intercept STDOUT with inputPipe
        dup2(inputPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        dup2(inputErrorPipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        
        dup2(stdinPipe.fileHandleForReading.fileDescriptor, stdinFileDescriptor)
    }
    
    /// Tears down the "tee" of piped output.
    public func closeConsolePipe() {
        // Restore stdout
        freopen("/dev/stdout", "a", stdout)
        freopen("/dev/stderr", "a", stdout)
        
        [inputPipe.fileHandleForReading, outputPipe.fileHandleForWriting].forEach { file in
            file.closeFile()
        }
    }
    
}
