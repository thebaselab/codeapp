//
//  Utilities.swift
//  Code
//
//  Created by Ken Chung on 12/11/2022.
//

import Foundation
import ios_system

func humanReadableByteCount(bytes: Int) -> String {
    if bytes < 1000 { return "\(bytes) B" }
    let exp = Int(log2(Double(bytes)) / log2(1000.0))
    let unit = ["KB", "MB", "GB", "TB", "PB", "EB"][exp - 1]
    let number = Double(bytes) / pow(1000, Double(exp))
    return String(format: "%.1f %@", number, unit)
}

struct CodableWrapper<Value: Codable> {
    var value: Value
}

// https://forums.swift.org/t/rawrepresentable-conformance-leads-to-crash/51912/4
extension CodableWrapper: RawRepresentable {

    typealias RawValue = String

    var rawValue: RawValue {
        guard
            let data = try? JSONEncoder().encode(value),
            let string = String(data: data, encoding: .utf8)
        else {
            // TODO: Track programmer error
            return ""
        }
        return string
    }

    init?(rawValue: RawValue) {
        guard
            let data = rawValue.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(Value.self, from: data)
        else {
            // TODO: Track programmer error
            return nil
        }
        value = decoded
    }
}

extension CodableWrapper: Equatable {
    static func == (lhs: CodableWrapper, rhs: CodableWrapper) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

// https://stackoverflow.com/questions/74372835/mutation-of-captured-var-in-concurrently-executing-code

class UnsafeTask<T> {
    let semaphore = DispatchSemaphore(value: 0)
    private var result: T?
    init(block: @escaping () async -> T) {
        Task {
            result = await block()
            semaphore.signal()
        }
    }

    func get() -> T {
        if let result = result { return result }
        semaphore.wait()
        return result!
    }
}

func refreshNodeCommands() {
    let nodeBinPath = Resources.appGroupSharedLibrary?.appendingPathComponent("lib/bin").path

    if let nodeBinPath = nodeBinPath,
        let paths = try? FileManager.default.contentsOfDirectory(atPath: nodeBinPath)
    {
        paths.forEach { path in
            let cmd = path.replacingOccurrences(of: nodeBinPath, with: "")
            replaceCommand(cmd, "nodeg", true)
        }
    }
}
