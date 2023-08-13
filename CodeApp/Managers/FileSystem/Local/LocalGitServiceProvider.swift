//
//  GitServiceProvider.swift
//  Code
//
//  Created by Ken Chung on 14/1/2021.
//

import Foundation
import SwiftGit2

extension Diff.Status: CaseIterable {
    public static var allCases: [SwiftGit2.Diff.Status] {
        [
            .conflicted, .current, .ignored, .indexDeleted, .indexModified, .indexNew,
            .indexRenamed, .indexTypeChange, .workTreeDeleted, .workTreeNew, .workTreeRenamed,
            .workTreeModified, .workTreeUnreadable, .workTreeTypeChange,
        ]
    }

    var allIncludedCases: [Diff.Status] {
        return Diff.Status.allCases.compactMap {
            if self.contains($0) { return $0 }
            return nil
        }
    }

    func str() -> String {
        switch self {
        case .conflicted:
            return "CONFLICTED"
        case .current:
            return "CURRENT"
        case .ignored:
            return "IGNORED"
        case .indexDeleted:
            return "INDEX_DELETED"
        case .indexModified:
            return "INDEX_MODIFIED"
        case .indexNew:
            return "INDEX_ADDED"
        case .indexRenamed:
            return "INDEX_RENAMED"
        case .indexTypeChange:
            return "INDEX_TYPE_CHANGED"
        case .workTreeDeleted:
            return "DELETED"
        case .workTreeNew:
            return "UNTRACKED"
        case .workTreeRenamed:
            return "RENAMED"
        case .workTreeModified:
            return "MODIFIED"
        case .workTreeUnreadable:
            return "UNREADABLE"
        case .workTreeTypeChange:
            return "TYPE_CHANGED"
        default:
            switch self.rawValue {
            case 257:  // Untracked -> Staged -> Modify content
                return "MODIFIED"
            case 258:  // Modified -> Staged -> Modify content
                return "MODIFIED"
            case 514:  // Untracked -> Staged -> Delete file
                return "DELETED"
            default:
                print("Unknown Status found: \(self)")
                return "UNKNOWN"
            }

        }
    }
}

class LocalGitServiceProvider: GitServiceProvider {

    private var workingURL: URL
    private var repository: Repository? = nil
    private var signature: Signature? = nil
    private var credential: Credentials? = nil
    private var contentCache = NSCache<NSString, NSString>()

    public var hasRepository: Bool {
        return repository != nil
    }
    public var requiresSignature: Bool {
        return signature == nil
    }
    private let workerQueue = DispatchQueue(label: "git.serial.queue", qos: .userInitiated)

    init(root: URL) {
        self.workingURL = root
        loadDirectory(url: root)
    }

    private func checkedRepository() throws -> Repository {
        if let repository {
            return repository
        } else {
            throw NSError(descriptionKey: "Repository doesn't exist")
        }
    }
    private func checkedSignature() throws -> Signature {
        if let signature {
            return signature
        } else {
            throw NSError(descriptionKey: "Signature is not configured")
        }
    }
    private func checkedCredentials() throws -> Credentials {
        if let credential {
            return credential
        } else {
            throw NSError(descriptionKey: "Credentials are not configured")
        }
    }
    private func WorkerQueueTask<T>(_ body: @escaping () throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            workerQueue.async {
                do {
                    continuation.resume(returning: try body())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func loadDirectory(url: URL) {
        contentCache.removeAllObjects()

        if url.absoluteString.contains("com.apple.filesystems.smbclientd") {
            return
        }
        workingURL = url

        if let usr_name = KeychainWrapper.standard.string(forKey: "git-username"),
            let usr_pwd = KeychainWrapper.standard.string(forKey: "git-password")
        {
            credential = Credentials.plaintext(username: usr_name, password: usr_pwd)
        }

        if let usr = UserDefaults.standard.object(forKey: "user_name") as? String,
            let email = UserDefaults.standard.object(forKey: "user_email") as? String
        {
            signature = Signature(name: usr, email: email)
        }
        load()
    }

    private func load() {
        repository = nil
        let result = Repository.at(workingURL)
        switch result {
        case .success(let repo):
            repository = repo
        case .failure(let error):
            print("Could not open repository: \(error)")
        }
    }

    func isCached(url: String) -> Bool {
        let path = url.replacingOccurrences(of: workingURL.absoluteString, with: "")
            .replacingOccurrences(of: "%20", with: #"\ "#)
        return contentCache.object(forKey: path as NSString) != nil
    }

    func sign(name: String, email: String) {
        signature = Signature(name: name, email: email)
    }

    func auth(name: String, password: String) {
        credential = Credentials.plaintext(username: name, password: password)
    }

    func aheadBehind(
        error: @escaping (NSError) -> Void, completionHandler: @escaping ((Int, Int)) -> Void
    ) {
        workerQueue.async {
            guard self.repository != nil else {
                let _error = NSError(
                    domain: "", code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Repository doesn't exist"])
                error(_error)
                return
            }

            let result = self.repository!.HEAD()
            switch result {
            case let .success(ref):
                guard let branchName = ref.shortName else {
                    // Error: In detached mode
                    let _error = NSError(
                        domain: "", code: 401,
                        userInfo: [NSLocalizedDescriptionKey: "Git is in detached mode"])
                    error(_error)
                    return
                }
                let result = self.repository!.remoteBranches()
                switch result {
                case let .success(branches):
                    for branch in branches {
                        if branch.longName.components(separatedBy: "/").dropFirst().joined(
                            separator: "/"
                        ).contains(branchName) {
                            let result = self.repository!.aheadBehind(
                                local: ref.oid, upstream: branch.oid)
                            switch result {
                            case let .success(tuple):
                                completionHandler(tuple)
                                return
                            case let .failure(err):
                                error(err)
                                return
                            }
                        }
                    }
                    let _error = NSError(
                        domain: "", code: 401,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot find upstream remote branch."]
                    )
                    error(_error)
                    return
                case let .failure(err):
                    error(err)
                    return
                }
            case let .failure(err):
                error(err)
                return
            }
        }
    }

    private func branch(long: Bool = false) -> String {
        let result = repository?.HEAD()
        switch result {
        case let .success(ref):
            if long {
                return ref.longName
            }
            if let shortName = ref.shortName {
                return shortName
            } else {
                // If shortName is not available, Git is in detached mode
                return String(ref.oid.description.dropLast(32))
            }
        default:
            return ""
        }
    }

    func status(
        error: @escaping (NSError) -> Void,
        completionHandler: @escaping ([(URL, Diff.Status)], [(URL, Diff.Status)], String) -> Void
    ) {
        workerQueue.async {
            self.load()
            guard self.repository != nil else {
                let _error = NSError(
                    domain: "", code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Repository doesn't exist"])
                error(_error)
                return
            }
            let result = self.repository!.status(options: [
                .recurseUntrackedDirs, .includeIgnored, .includeUntracked, .excludeSubmodules,
            ])
            switch result {
            case let .success(entries):
                var indexedGroup = [(URL, Diff.Status)]()
                var workingGroup = [(URL, Diff.Status)]()

                for i in entries {
                    let status = i.status

                    let headToIndexURL: URL? = {
                        guard let path = i.headToIndex?.newFile?.path else {
                            return nil
                        }
                        return self.workingURL.appendingPathComponent(path)
                    }()
                    let indexToWorkURL: URL? = {
                        guard let path = i.indexToWorkDir?.newFile?.path else {
                            return nil
                        }
                        return self.workingURL.appendingPathComponent(path)
                    }()

                    status.allIncludedCases.forEach { includedCase in
                        if [
                            .indexDeleted, .indexRenamed, .indexModified, .indexDeleted,
                            .indexTypeChange, .indexNew,
                        ].contains(includedCase) {
                            indexedGroup.append((headToIndexURL!, includedCase))
                        } else if [
                            .workTreeNew, .workTreeDeleted, .workTreeRenamed, .workTreeModified,
                            .workTreeUnreadable, .workTreeTypeChange, .conflicted,
                        ].contains(includedCase) {
                            workingGroup.append((indexToWorkURL!, includedCase))
                        }
                    }
                }
                completionHandler(indexedGroup, workingGroup, self.branch())
            case let .failure(_error):
                error(_error)
            }
        }
    }

    func initialize(error: @escaping (NSError) -> Void, completionHandler: @escaping () -> Void) {
        workerQueue.async {
            guard self.repository == nil else {
                let _error = NSError(
                    domain: "", code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Repository already exists"])
                error(_error)
                return
            }
            let result = Repository.create(at: self.workingURL)
            switch result {
            case let .success(repo):
                self.repository = repo
                completionHandler()
            case let .failure(err):
                error(err)
            }
        }

    }

    func clone(
        from: URL, to: URL, progress: Progress?, error: @escaping (NSError) -> Void,
        completionHandler: @escaping () -> Void
    ) {
        workerQueue.async {
            progress?.fileOperationKind = .downloading
            var result: Result<Repository, NSError>
            if self.credential == nil {
                result = Repository.clone(
                    from: from, to: to,
                    checkoutProgress: { (message, current, total) in
                        DispatchQueue.main.async {
                            progress?.localizedDescription = "Updating files"
                            progress?.totalUnitCount = Int64(total)
                            progress?.completedUnitCount = Int64(current)
                        }
                    },
                    fetchProgress: { current, total in
                        DispatchQueue.main.async {
                            progress?.localizedDescription = "Receiving objects"
                            progress?.fileOperationKind = .downloading
                            progress?.totalUnitCount = Int64(total)
                            progress?.completedUnitCount = Int64(current)
                        }
                    }
                )
            } else {
                result = Repository.clone(
                    from: from, to: to, credentials: self.credential!,
                    checkoutProgress: { (message, current, total) in
                        DispatchQueue.main.async {
                            progress?.localizedDescription = "Updating files"
                            progress?.totalUnitCount = Int64(total)
                            progress?.completedUnitCount = Int64(current)
                        }
                    },
                    fetchProgress: { current, total in
                        DispatchQueue.main.async {
                            progress?.localizedDescription = "Receiving objects"
                            progress?.fileOperationKind = .downloading
                            progress?.totalUnitCount = Int64(total)
                            progress?.completedUnitCount = Int64(current)
                        }
                    }
                )
            }
            switch result {
            case .success:
                DispatchQueue.main.async {
                    completionHandler()
                }
            case let .failure(_error):
                DispatchQueue.main.async {
                    progress?.cancel()
                    error(_error)
                }
            }
        }
    }

    func commit(message: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            workerQueue.async {
                do {
                    guard let repository = self.repository else {
                        throw NSError(descriptionKey: "Repository doesn't exist")
                    }
                    guard let signature = self.signature else {
                        throw NSError(descriptionKey: "Signature is not configured")
                    }

                    let isMerging = repository.repositoryState().contains(.merge)
                    if isMerging {
                        let head = try repository.HEAD().get()
                        let oids = try [head.oid] + repository.enumerateMergeHeadEntries()
                        let parents = try oids.map { oid in
                            try repository.commit(oid).get()
                        }
                        let treeOid = try repository.writeIndexAsTree()

                        _ = try repository.commit(
                            tree: treeOid, parents: parents, message: message, signature: signature
                        ).get()
                    } else {
                        _ = try repository.commit(message: message, signature: signature).get()
                    }
                    self.contentCache.removeAllObjects()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func createBranch(name: String, oid: OID) -> [String: Any] {
        let result = repository!.commit(oid)
        switch result {
        case let .success(commit):
            let result = repository!.createBranch(at: commit, branchName: name)
            switch result {
            case let .success(branch):
                let result = repository!.setHEAD(branch)
                switch result {
                case .success:
                    return ["result": "OK"]
                case let .failure(error):
                    return ["result": "Failed", "error": error.localizedDescription]
                }
            case let .failure(error):
                return ["result": "Failed", "error": error.localizedDescription]
            }
        case let .failure(error):
            return ["result": "Failed", "error": error.localizedDescription]
        }

    }

    private func createBranch(name: String) -> [String: Any] {
        guard repository != nil else {
            return ["result": "Failed", "error": "There is no repository."]
        }
        let result = repository!.HEAD()
        switch result {
        case let .success(ref):
            return createBranch(name: name, oid: ref.oid)
        case let .failure(error):
            return ["result": "Failed", "error": error.localizedDescription]
        }
    }

    private func createBranch(name: String, fromTag tagName: String) -> [String: Any] {
        guard repository != nil else {
            return ["result": "Failed", "error": "There is no repository."]
        }
        let result = repository!.tag(named: tagName)
        switch result {
        case let .success(tag):
            let result = repository!.checkout(tag, strategy: .Force)
            switch result {
            case .success:
                return createBranch(name: name, oid: tag.oid)
            case let .failure(error):
                return ["result": "Failed", "error": error.localizedDescription]
            }
        case let .failure(error):
            return ["result": "Failed", "error": error.localizedDescription]
        }
    }

    private func createBranch(name: String, fromLocalBranch localBranchName: String) -> [String:
        Any]
    {
        guard repository != nil else {
            return ["result": "Failed", "error": "There is no repository."]
        }
        let result = repository!.localBranch(named: localBranchName)
        switch result {
        case let .success(branch):
            let result = repository!.checkout(branch, strategy: .Force)
            switch result {
            case .success:
                return createBranch(name: name, oid: branch.oid)
            case let .failure(error):
                return ["result": "Failed", "error": error.localizedDescription]
            }
        case let .failure(error):
            return ["result": "Failed", "error": error.localizedDescription]
        }
    }

    private func createBranch(name: String, fromRemoteBranch remoteBranchName: String) -> [String:
        Any]
    {
        guard repository != nil else {
            return ["result": "Failed", "error": "There is no repository"]
        }
        let result = repository!.remoteBranch(named: remoteBranchName)
        switch result {
        case let .success(branch):
            let result = repository!.checkout(branch, strategy: .Force)
            switch result {
            case .success:
                return createBranch(name: name, oid: branch.oid)
            case let .failure(error):
                return ["result": "Failed", "error": error.localizedDescription]
            }
        case let .failure(error):
            return ["result": "Failed", "error": error.localizedDescription]
        }
    }

    func unstage(paths: [String]) throws {
        guard repository != nil else {
            let error = NSError(
                domain: "", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Repository doesn't exist"])
            throw error
        }
        for path in paths {
            let path = path.replacingOccurrences(of: workingURL.absoluteString, with: "")
                .replacingOccurrences(of: "%20", with: #"\ "#)
            let result = repository!.unstage(path: path)
            switch result {
            case .success:
                continue
            case let .failure(error):
                throw error
            }
        }
    }

    func stage(paths: [String]) throws {
        guard repository != nil else {
            let error = NSError(
                domain: "", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Repository doesn't exist"])
            throw error
        }
        for path in paths {
            let path = path.replacingOccurrences(of: workingURL.absoluteString, with: "")
                .removingPercentEncoding!
            let result = repository!.add(path: path)
            switch result {
            case .success:
                continue
            case let .failure(error):
                throw error
            }
        }
    }

    private func checkout(oid: OID) throws {
        let result = repository!.checkout(oid, strategy: .Force)
        switch result {
        case .success:
            contentCache.removeAllObjects()
            return
        case let .failure(error):
            throw error
        }
    }

    private func checkout(ref: ReferenceType, createBranch: Bool) throws {
        let result = repository!.checkout(ref, strategy: .Force)
        switch result {
        case .success:
            if createBranch {
                let result = repository!.commit(ref.oid)
                switch result {
                case let .success(commit):
                    var result: Result<Branch, NSError>
                    if ref.longName.hasPrefix("refs/tags/") {
                        result = repository!.createBranch(
                            at: commit,
                            branchName: String(ref.longName.dropFirst("refs/tags/".count)))
                    } else {
                        result = repository!.createBranch(
                            at: commit,
                            branchName: ref.longName.components(separatedBy: "/").dropFirst(3)
                                .joined(separator: "/"))
                    }
                    switch result {
                    case let .success(branch):
                        let result = repository!.setHEAD(branch)
                        switch result {
                        case .success:
                            contentCache.removeAllObjects()
                            return
                        case let .failure(error):
                            throw error
                        }
                    case let .failure(error):
                        throw error
                    }
                case let .failure(error):
                    throw error
                }
            } else {
                return
            }
        case let .failure(error):
            throw error
        }
    }

    func checkout(
        tagName: String, detached: Bool, error: @escaping (NSError) -> Void,
        completionHandler: @escaping () -> Void
    ) {
        workerQueue.async {
            guard self.repository != nil else {
                let _error = NSError(
                    domain: "", code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Repository doesn't exist"])
                error(_error)
                return
            }
            let result = self.repository!.tag(named: tagName)
            switch result {
            case let .success(tag):
                do {
                    if detached {
                        try self.checkout(oid: tag.oid)
                    } else {
                        try self.checkout(ref: tag, createBranch: true)
                    }
                } catch let _error {
                    error(_error as NSError)
                    return
                }
                completionHandler()
            case let .failure(_error):
                error(_error)
            }
        }
    }

    func checkout(
        localBranchName: String, detached: Bool, error: @escaping (NSError) -> Void,
        completionHandler: @escaping () -> Void
    ) {
        workerQueue.async {
            guard self.repository != nil else {
                let _error = NSError(
                    domain: "", code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Repository doesn't exist"])
                error(_error)
                return
            }
            let result = self.repository!.localBranch(named: localBranchName)
            switch result {
            case let .success(branch):
                do {
                    if detached {
                        try self.checkout(oid: branch.oid)
                    } else {
                        try self.checkout(ref: branch, createBranch: false)
                    }
                } catch let _error {
                    error(_error as NSError)
                    return
                }
                completionHandler()
            case let .failure(_error):
                error(_error)
            }
        }
    }

    func checkout(
        remoteBranchName: String, detached: Bool, error: @escaping (NSError) -> Void,
        completionHandler: @escaping () -> Void
    ) {
        workerQueue.async {
            guard self.repository != nil else {
                let _error = NSError(
                    domain: "", code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Repository doesn't exist"])
                error(_error)
                return
            }
            let result = self.repository!.remoteBranch(named: remoteBranchName)
            switch result {
            case let .success(branch):
                do {
                    if detached {
                        try self.checkout(oid: branch.oid)
                    } else {
                        try self.checkout(ref: branch, createBranch: true)
                    }
                } catch let _error {
                    error(_error as NSError)
                    return
                }
                completionHandler()
            case let .failure(_error):
                error(_error)
            }
        }
    }

    func checkout(paths: [String]) throws {
        guard repository != nil else {
            throw NSError(
                domain: "", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "There is no repository to checkout"])
        }
        for path in paths {
            let path = path.replacingOccurrences(of: workingURL.absoluteString, with: "")
                .replacingOccurrences(of: "%20", with: #"\ "#)
            let result = repository!.checkout(path: path, strategy: .Force)
            switch result {
            case .success:
                continue
            case let .failure(error):
                throw error
            }
        }
    }

    func remotes() async throws -> [Remote] {
        guard let repository = self.repository else {
            throw NSError(
                domain: "", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Repository doesn't exist"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            workerQueue.async {
                let result = repository.allRemotes()
                switch result {
                case let .success(remotes):
                    continuation.resume(returning: remotes)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func push(
        error: @escaping (NSError) -> Void, remote: String, progress: Progress?,
        completionHandler: @escaping () -> Void
    ) {
        workerQueue.async {
            guard self.repository != nil else {
                let _error = NSError(
                    domain: "", code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Repository doesn't exist"])
                error(_error)
                return
            }
            guard self.credential != nil else {
                let _error = NSError(
                    domain: "", code: -16,
                    userInfo: [NSLocalizedDescriptionKey: "Credentials are not configured"])
                error(_error)
                return
            }
            let result = self.repository!.allRemotes()
            switch result {
            case let .success(remotes):
                let result: Result<(), NSError>
                if remotes.map({ $0.name }).contains(remote) {
                    result = self.repository!.push(
                        credentials: self.credential!, branch: self.branch(long: true),
                        remoteName: remote,
                        progress: { current, total in
                            DispatchQueue.main.async {
                                progress?.totalUnitCount = Int64(current)
                                progress?.completedUnitCount = Int64(total)
                            }
                        })
                    switch result {
                    case .success:
                        completionHandler()
                    case let .failure(_error):
                        error(_error)
                    }
                } else {
                    let _error = NSError(
                        domain: "", code: 401,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "The specified remote does not exist"
                        ])
                    error(_error)
                    return
                }
            case let .failure(_error):
                error(_error)
                return
            }
        }
    }

    func hasRemote() -> Bool {
        guard repository != nil else {
            return false
        }
        let result = repository!.allRemotes()
        switch result {
        case let .success(remotes):
            if remotes.isEmpty {
                return false
            } else {
                return true
            }
        default:
            return false
        }
    }

    func remoteBranches() async throws -> [Branch] {
        guard let repository = self.repository else {
            throw NSError(
                domain: "", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Repository doesn't exist"])
        }
        return try await withCheckedThrowingContinuation { continuation in
            workerQueue.async {
                switch repository.remoteBranches() {
                case .success(let branches):
                    continuation.resume(returning: branches)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func checkoutDestinations() -> [checkoutDest] {
        return branches(isRemote: true) + branches(isRemote: false) + tags()
    }

    func branches(isRemote: Bool = false) -> [checkoutDest] {
        guard repository != nil else {
            return []
        }
        let result: Result<[Branch], NSError>

        if isRemote {
            result = repository!.remoteBranches()
        } else {
            result = repository!.localBranches()
        }

        switch result {
        case let .success(branches):
            var output = [checkoutDest]()
            for branch in branches {
                output.append(
                    checkoutDest.init(
                        oid: String(branch.oid.description.dropLast(32)), name: branch.name,
                        type: isRemote ? .remote_branch : .local_branch))
            }
            return output
        default:
            return []
        }
    }

    func tags() -> [checkoutDest] {
        guard repository != nil else {
            return []
        }
        let result = repository!.allTags()
        switch result {
        case let .success(tags):
            var output = [checkoutDest]()
            for tag in tags {
                output.append(
                    checkoutDest.init(
                        oid: String(tag.oid.description.dropLast(32)), name: tag.name, type: .tag))
            }
            return output
        default:
            return []
        }
    }
    
    /// Returns the OID of the path at the current HEAD
    private func fileOidAtPathForLastCommit(path: String) throws -> OID {
        let repository = try self.checkedRepository()
        let entries = try repository.status(options: [.includeUnmodified]).get()
        for entry in entries {
            if let oldFilePath = entry.headToIndex?.oldFile?.path,
               path == oldFilePath,
               let oid = entry.headToIndex?.oldFile?.oid {
                return oid
            }
        }
        throw NSError(descriptionKey: "Unable to locate OID for \(path)")
    }
    
    func previous(path: String) async throws -> String {
        return try await WorkerQueueTask {
            let repository = try self.checkedRepository()
            
            if let cached = self.contentCache.object(forKey: path as NSString) {
                return (cached as String)
            }
            let path = path.replacingOccurrences(of: self.workingURL.absoluteString, with: "")
                .replacingOccurrences(of: "%20", with: #"\ "#)

            let oid = try self.fileOidAtPathForLastCommit(path: path)
            let blob = try repository.blob(oid).get()
            
            guard let content = String(data: blob.data, encoding: .utf8) else {
                throw NSError(descriptionKey: "Unable to decode data")
            }
            self.contentCache.setObject(content as NSString, forKey: path as NSString)
            return content
        }
    }

    func pull(branch: Branch, remote from: Remote) async throws {
        try await WorkerQueueTask {
            let repository = try self.checkedRepository()
            let credentials = try self.checkedCredentials()
            let signature = try self.checkedSignature()
            try repository.pull(
                branch: branch, from: from, credentials: credentials, signature: signature)
        }
    }

    func fetch(remote from: Remote) async throws {
        try await WorkerQueueTask {
            let repository = try self.checkedRepository()
            let credentials = try self.checkedCredentials()
            try repository.fetch(from, credentials: credentials).get()
        }
    }
}
