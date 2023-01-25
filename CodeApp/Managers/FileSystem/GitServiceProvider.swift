//
//  GitServiceProvider.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import Foundation
import SwiftGit2

struct checkoutDest: Identifiable {
    let oid: String
    let name: String
    let id = UUID()
    let type: type
    enum type {
        case local_branch
        case remote_branch
        case tag
    }
}

protocol GitServiceProvider {
    var hasRepository: Bool { get }
    var requiresSignature: Bool { get }
    func loadDirectory(url: URL)
    func isCached(url: String) -> Bool
    func sign(name: String, email: String)
    func auth(name: String, password: String)
    func aheadBehind(
        error: @escaping (NSError) -> Void, completionHandler: @escaping ((Int, Int)) -> Void)
    func status(
        error: @escaping (NSError) -> Void,
        completionHandler: @escaping ([(URL, Diff.Status)], [(URL, Diff.Status)], String) -> Void
    )
    func initialize(error: @escaping (NSError) -> Void, completionHandler: @escaping () -> Void)
    func clone(
        from: URL, to: URL, progress: Progress?, error: @escaping (NSError) -> Void,
        completionHandler: @escaping () -> Void
    )
    func commit(
        message: String, error: @escaping (NSError) -> Void, completionHandler: @escaping () -> Void
    )
    func unstage(paths: [String]) throws
    func stage(paths: [String]) throws
    func fetch(error: @escaping (NSError) -> Void, completionHandler: @escaping () -> Void)
    func checkout(
        tagName: String, detached: Bool, error: @escaping (NSError) -> Void,
        completionHandler: @escaping () -> Void
    )
    func checkout(
        localBranchName: String, detached: Bool, error: @escaping (NSError) -> Void,
        completionHandler: @escaping () -> Void
    )
    func checkout(
        remoteBranchName: String, detached: Bool, error: @escaping (NSError) -> Void,
        completionHandler: @escaping () -> Void
    )
    func checkout(paths: [String]) throws
    func push(
        error: @escaping (NSError) -> Void, remote: String, progress: Progress?,
        completionHandler: @escaping () -> Void)
    func hasRemote() -> Bool
    func checkoutDestinations() -> [checkoutDest]
    func branches(isRemote: Bool) -> [checkoutDest]
    func tags() -> [checkoutDest]
    func previous(
        path: String, error: @escaping (NSError) -> Void,
        completionHandler: @escaping (String) -> Void
    )
    func remotes() async throws -> [Remote]
}
