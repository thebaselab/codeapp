//
//  GitServiceProvider.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import Foundation
import SwiftGit2

protocol GitServiceProvider {
    var hasRepository: Bool { get }
    var requiresSignature: Bool { get }
    func loadDirectory(url: URL)
    func isCached(url: String) -> Bool
    func sign(name: String, email: String)
    func auth(name: String, password: String)
    func initialize(error: @escaping (NSError) -> Void, completionHandler: @escaping () -> Void)
    func clone(
        from: URL, to: URL, progress: Progress?, error: @escaping (NSError) -> Void,
        completionHandler: @escaping () -> Void
    )
    func commit(message: String) async throws
    func unstage(paths: [String]) throws
    func stage(paths: [String]) throws
    func checkout(paths: [String]) throws
    func currentBranch() async throws -> Branch
    func push(branch: Branch, remote to: Remote, progress: Progress?) async throws
    func tags() async throws -> [TagReference]
    func remotes() async throws -> [Remote]
    func pull(branch: Branch, remote from: Remote) async throws
    func fetch(remote from: Remote) async throws
    func remoteBranches() async throws -> [Branch]
    func localBranches() async throws -> [Branch]
    func previous(path: String) async throws -> String
    func checkout(oid: OID) async throws
    func aheadBehind(remote: Remote?) async throws -> (Int, Int)
    func status() async throws -> [StatusEntry]
}
