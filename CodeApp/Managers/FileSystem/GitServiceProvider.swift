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
    func createRepository() async throws
    func clone(from: URL, to: URL, progress: Progress?) async throws
    func commit(message: String) async throws
    func unstage(paths: [String]) async throws
    func stage(paths: [String]) async throws
    func checkout(paths: [String]) async throws
    func head() async throws -> ReferenceType
    func push(branch: Branch, remote to: Remote, progress: Progress?) async throws
    func push(tag: TagReference, remote to: Remote, progress: Progress?) async throws
    func tags() async throws -> [TagReference]
    func remotes() async throws -> [Remote]
    func pull(branch: Branch, remote from: Remote) async throws
    func fetch(remote from: Remote) async throws
    func remoteBranches() async throws -> [Branch]
    func localBranches() async throws -> [Branch]
    func previous(path: String) async throws -> String
    func checkout(reference: ReferenceType) async throws
    func checkout(oid: OID) async throws
    func aheadBehind(remote: Remote?) async throws -> (Int, Int)
    func status() async throws -> [StatusEntry]
    func lookupCommit(oid: OID) async throws -> Commit
    func createBranch(at: Commit, branchName: String) async throws -> Branch
    func deleteBranch(branch: Branch) async throws
    func createTag(at: OID, tagName: String, annotation: String?) async throws
    func deleteTag(tag: TagReference) async throws
}
