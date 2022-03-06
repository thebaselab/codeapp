//
//  RepositorySpec.swift
//  RepositorySpec
//
//  Created by Matt Diephouse on 11/7/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import SwiftGit2
import Nimble
import Quick
import Foundation

// swiftlint:disable cyclomatic_complexity

class RepositorySpec: FixturesSpec {
	override func spec() {
		describe("Repository.Type.at(_:)") {
			it("should work if the repo exists") {
				let repo = Fixtures.simpleRepository
				expect(repo.directoryURL).notTo(beNil())
			}

			it("should fail if the repo doesn't exist") {
				let url = URL(fileURLWithPath: "blah")
				let result = Repository.at(url)
				expect(result.error?.domain) == libGit2ErrorDomain
				expect(result.error?.localizedDescription).to(match("failed to resolve path"))
			}
		}

		describe("Repository.Type.isValid(url:)") {
			it("should return true if the repo exists") {
				guard let repositoryURL = Fixtures.simpleRepository.directoryURL else {
					fail("Fixture setup broken: Repository does not exist"); return
				}

				let result = Repository.isValid(url: repositoryURL)

				expect(result.error).to(beNil())

				if case .success(let isValid) = result {
					expect(isValid).to(beTruthy())
				}
			}

			it("should return false if the directory does not contain a repo") {
				let tmpURL = URL(fileURLWithPath: "/dev/null")
				let result = Repository.isValid(url: tmpURL)

				expect(result.error).to(beNil())

				if case .success(let isValid) = result {
					expect(isValid).to(beFalsy())
				}
			}

			it("should return error if .git is not readable") {
				let localURL = self.temporaryURL(forPurpose: "git-isValid-unreadable").appendingPathComponent(".git")
				let nonReadablePermissions: [FileAttributeKey: Any] = [.posixPermissions: 0o077]
				try! FileManager.default.createDirectory(
					at: localURL,
					withIntermediateDirectories: true,
					attributes: nonReadablePermissions)
				let result = Repository.isValid(url: localURL)

				expect(result.value).to(beNil())
				expect(result.error).notTo(beNil())
			}
		}

		describe("Repository.Type.create(at:)") {
			it("should create a new repo at the specified location") {
				let localURL = self.temporaryURL(forPurpose: "local-create")
				let result = Repository.create(at: localURL)

				expect(result.error).to(beNil())

				if case .success(let clonedRepo) = result {
					expect(clonedRepo.directoryURL).notTo(beNil())
				}
			}
		}

		describe("Repository.Type.clone(from:to:)") {
			it("should handle local clones") {
				let remoteRepo = Fixtures.simpleRepository
				let localURL = self.temporaryURL(forPurpose: "local-clone")
				let result = Repository.clone(from: remoteRepo.directoryURL!, to: localURL, localClone: true)

				expect(result.error).to(beNil())

				if case .success(let clonedRepo) = result {
					expect(clonedRepo.directoryURL).notTo(beNil())
				}
			}

			it("should handle bare clones") {
				let remoteRepo = Fixtures.simpleRepository
				let localURL = self.temporaryURL(forPurpose: "bare-clone")
				let result = Repository.clone(from: remoteRepo.directoryURL!, to: localURL, localClone: true, bare: true)

				expect(result.error).to(beNil())

				if case .success(let clonedRepo) = result {
					expect(clonedRepo.directoryURL).to(beNil())
				}
			}

			it("should have set a valid remote url") {
				let remoteRepo = Fixtures.simpleRepository
				let localURL = self.temporaryURL(forPurpose: "valid-remote-clone")
				let cloneResult = Repository.clone(from: remoteRepo.directoryURL!, to: localURL, localClone: true)

				expect(cloneResult.error).to(beNil())

				if case .success(let clonedRepo) = cloneResult {
					let remoteResult = clonedRepo.remote(named: "origin")
					expect(remoteResult.error).to(beNil())

					if case .success(let remote) = remoteResult {
						expect(remote.URL).to(equal(remoteRepo.directoryURL?.absoluteString))
					}
				}
			}

			it("should be able to clone a remote repository") {
				let remoteRepoURL = URL(string: "https://github.com/libgit2/libgit2.github.com.git")
				let localURL = self.temporaryURL(forPurpose: "public-remote-clone")
				let cloneResult = Repository.clone(from: remoteRepoURL!, to: localURL)

				expect(cloneResult.error).to(beNil())

				if case .success(let clonedRepo) = cloneResult {
					let remoteResult = clonedRepo.remote(named: "origin")
					expect(remoteResult.error).to(beNil())

					if case .success(let remote) = remoteResult {
						expect(remote.URL).to(equal(remoteRepoURL?.absoluteString))
					}
				}
			}

			let env = ProcessInfo.processInfo.environment

			if let privateRepo = env["SG2TestPrivateRepo"],
			   let gitUsername = env["SG2TestUsername"],
			   let publicKey = env["SG2TestPublicKey"],
			   let privateKey = env["SG2TestPrivateKey"],
			   let passphrase = env["SG2TestPassphrase"] {

				it("should be able to clone a remote repository requiring credentials") {
					let remoteRepoURL = URL(string: privateRepo)
					let localURL = self.temporaryURL(forPurpose: "private-remote-clone")
					let credentials = Credentials.sshMemory(username: gitUsername,
					                                        publicKey: publicKey,
					                                        privateKey: privateKey,
					                                        passphrase: passphrase)

					let cloneResult = Repository.clone(from: remoteRepoURL!, to: localURL, credentials: credentials)

					expect(cloneResult.error).to(beNil())

					if case .success(let clonedRepo) = cloneResult {
						let remoteResult = clonedRepo.remote(named: "origin")
						expect(remoteResult.error).to(beNil())

						if case .success(let remote) = remoteResult {
							expect(remote.URL).to(equal(remoteRepoURL?.absoluteString))
						}
					}
				}
			}
		}

		describe("Repository.blob(_:)") {
			it("should return the commit if it exists") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "41078396f5187daed5f673e4a13b185bbad71fba")!

				let result = repo.blob(oid)
				expect(result.map { $0.oid }.value) == oid
			}

			it("should error if the blob doesn't exist") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")!

				let result = repo.blob(oid)
				expect(result.error?.domain) == libGit2ErrorDomain
			}

			it("should error if the oid doesn't point to a blob") {
				let repo = Fixtures.simpleRepository
				// This is a tree in the repository
				let oid = OID(string: "f93e3a1a1525fb5b91020da86e44810c87a2d7bc")!

				let result = repo.blob(oid)
				expect(result.error).notTo(beNil())
			}
		}

		describe("Repository.commit(_:)") {
			it("should return the commit if it exists") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "dc220a3f0c22920dab86d4a8d3a3cb7e69d6205a")!

				let result = repo.commit(oid)
				expect(result.map { $0.oid }.value) == oid
			}

			it("should error if the commit doesn't exist") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")!

				let result = repo.commit(oid)
				expect(result.error?.domain) == libGit2ErrorDomain
			}

			it("should error if the oid doesn't point to a commit") {
				let repo = Fixtures.simpleRepository
				// This is a tree in the repository
				let oid = OID(string: "f93e3a1a1525fb5b91020da86e44810c87a2d7bc")!

				let result = repo.commit(oid)
				expect(result.error?.domain) == libGit2ErrorDomain
			}
		}

		describe("Repository.tag(_:)") {
			it("should return the tag if it exists") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "57943b8ee00348180ceeedc960451562750f6d33")!

				let result = repo.tag(oid)
				expect(result.map { $0.oid }.value) == oid
			}

			it("should error if the tag doesn't exist") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")!

				let result = repo.tag(oid)
				expect(result.error?.domain) == libGit2ErrorDomain
			}

			it("should error if the oid doesn't point to a tag") {
				let repo = Fixtures.simpleRepository
				// This is a commit in the repository
				let oid = OID(string: "dc220a3f0c22920dab86d4a8d3a3cb7e69d6205a")!

				let result = repo.tag(oid)
				expect(result.error?.domain) == libGit2ErrorDomain
			}
		}

		describe("Repository.tree(_:)") {
			it("should return the tree if it exists") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "f93e3a1a1525fb5b91020da86e44810c87a2d7bc")!

				let result = repo.tree(oid)
				expect(result.map { $0.oid }.value) == oid
			}

			it("should error if the tree doesn't exist") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")!

				let result = repo.tree(oid)
				expect(result.error?.domain) == libGit2ErrorDomain
			}

			it("should error if the oid doesn't point to a tree") {
				let repo = Fixtures.simpleRepository
				// This is a commit in the repository
				let oid = OID(string: "dc220a3f0c22920dab86d4a8d3a3cb7e69d6205a")!

				let result = repo.tree(oid)
				expect(result.error?.domain) == libGit2ErrorDomain
			}
		}

		describe("Repository.object(_:)") {
			it("should work with a blob") {
				let repo   = Fixtures.simpleRepository
				let oid    = OID(string: "41078396f5187daed5f673e4a13b185bbad71fba")!
				let blob   = repo.blob(oid).value
				let result = repo.object(oid)
				expect(result.map { $0 as! Blob }.value) == blob
			}

			it("should work with a commit") {
				let repo   = Fixtures.simpleRepository
				let oid    = OID(string: "dc220a3f0c22920dab86d4a8d3a3cb7e69d6205a")!
				let commit = repo.commit(oid).value
				let result = repo.object(oid)
				expect(result.map { $0 as! Commit }.value) == commit
			}

			it("should work with a tag") {
				let repo   = Fixtures.simpleRepository
				let oid    = OID(string: "57943b8ee00348180ceeedc960451562750f6d33")!
				let tag    = repo.tag(oid).value
				let result = repo.object(oid)
				expect(result.map { $0 as! Tag }.value) == tag
			}

			it("should work with a tree") {
				let repo   = Fixtures.simpleRepository
				let oid    = OID(string: "f93e3a1a1525fb5b91020da86e44810c87a2d7bc")!
				let tree   = repo.tree(oid).value
				let result = repo.object(oid)
				expect(result.map { $0 as! Tree }.value) == tree
			}

			it("should error if there's no object with that oid") {
				let repo   = Fixtures.simpleRepository
				let oid    = OID(string: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")!
				let result = repo.object(oid)
				expect(result.error?.domain) == libGit2ErrorDomain
			}
		}

		describe("Repository.object(from: PointerTo)") {
			it("should work with commits") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "dc220a3f0c22920dab86d4a8d3a3cb7e69d6205a")!

				let pointer = PointerTo<Commit>(oid)
				let commit = repo.commit(oid).value!
				expect(repo.object(from: pointer).value) == commit
			}

			it("should work with trees") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "f93e3a1a1525fb5b91020da86e44810c87a2d7bc")!

				let pointer = PointerTo<Tree>(oid)
				let tree = repo.tree(oid).value!
				expect(repo.object(from: pointer).value) == tree
			}

			it("should work with blobs") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "41078396f5187daed5f673e4a13b185bbad71fba")!

				let pointer = PointerTo<Blob>(oid)
				let blob = repo.blob(oid).value!
				expect(repo.object(from: pointer).value) == blob
			}

			it("should work with tags") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "57943b8ee00348180ceeedc960451562750f6d33")!

				let pointer = PointerTo<Tag>(oid)
				let tag = repo.tag(oid).value!
				expect(repo.object(from: pointer).value) == tag
			}
		}

		describe("Repository.object(from: Pointer)") {
			it("should work with commits") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "dc220a3f0c22920dab86d4a8d3a3cb7e69d6205a")!

				let pointer = Pointer.commit(oid)
				let commit = repo.commit(oid).value!
				let result = repo.object(from: pointer).map { $0 as! Commit }
				expect(result.value) == commit
			}

			it("should work with trees") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "f93e3a1a1525fb5b91020da86e44810c87a2d7bc")!

				let pointer = Pointer.tree(oid)
				let tree = repo.tree(oid).value!
				let result = repo.object(from: pointer).map { $0 as! Tree }
				expect(result.value) == tree
			}

			it("should work with blobs") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "41078396f5187daed5f673e4a13b185bbad71fba")!

				let pointer = Pointer.blob(oid)
				let blob = repo.blob(oid).value!
				let result = repo.object(from: pointer).map { $0 as! Blob }
				expect(result.value) == blob
			}

			it("should work with tags") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "57943b8ee00348180ceeedc960451562750f6d33")!

				let pointer = Pointer.tag(oid)
				let tag = repo.tag(oid).value!
				let result = repo.object(from: pointer).map { $0 as! Tag }
				expect(result.value) == tag
			}
		}

		describe("Repository.allRemotes()") {
			it("should return an empty list if there are no remotes") {
				let repo = Fixtures.simpleRepository
				let result = repo.allRemotes()
				expect(result.value) == []
			}

			it("should return all the remotes") {
				let repo = Fixtures.mantleRepository
				let remotes = repo.allRemotes()
				let names = remotes.map { $0.map { $0.name } }
				expect(remotes.map { $0.count }.value) == 2
				expect(names.value).to(contain("origin", "upstream"))
			}
		}

		describe("Repository.remote(named:)") {
			it("should return the remote if it exists") {
				let repo = Fixtures.mantleRepository
				let result = repo.remote(named: "upstream")
				expect(result.map { $0.name }.value) == "upstream"
			}

			it("should error if the remote doesn't exist") {
				let repo = Fixtures.simpleRepository
				let result = repo.remote(named: "nonexistent")
				expect(result.error?.domain) == libGit2ErrorDomain
			}
		}

		describe("Repository.reference(named:)") {
			it("should return a local branch if it exists") {
				let name = "refs/heads/master"
				let result = Fixtures.simpleRepository.reference(named: name)
				expect(result.map { $0.longName }.value) == name
				expect(result.value as? Branch).notTo(beNil())
			}

			it("should return a remote branch if it exists") {
				let name = "refs/remotes/upstream/master"
				let result = Fixtures.mantleRepository.reference(named: name)
				expect(result.map { $0.longName }.value) == name
				expect(result.value as? Branch).notTo(beNil())
			}

			it("should return a tag if it exists") {
				let name = "refs/tags/tag-2"
				let result = Fixtures.simpleRepository.reference(named: name)
				expect(result.value?.longName).to(equal(name))
				expect(result.value as? TagReference).notTo(beNil())
			}

			it("should return the reference if it exists") {
				let name = "refs/other-ref"
				let result = Fixtures.simpleRepository.reference(named: name)
				expect(result.value?.longName).to(equal(name))
			}

			it("should error if the reference doesn't exist") {
				let result = Fixtures.simpleRepository.reference(named: "refs/heads/nonexistent")
				expect(result.error?.domain) == libGit2ErrorDomain
			}
		}

		describe("Repository.localBranches()") {
			it("should return all the local branches") {
				let repo = Fixtures.simpleRepository
				let expected = [
					repo.localBranch(named: "another-branch").value!,
					repo.localBranch(named: "master").value!,
					repo.localBranch(named: "yet-another-branch").value!,
				]
				expect(repo.localBranches().value).to(equal(expected))
			}
		}

		describe("Repository.remoteBranches()") {
			it("should return all the remote branches") {
				let repo = Fixtures.mantleRepository
				let expectedNames = [
					"origin/2.0-development",
					"origin/HEAD",
					"origin/bump-config",
					"origin/bump-xcconfigs",
					"origin/github-reversible-transformer",
					"origin/master",
					"origin/mtlmanagedobject",
					"origin/reversible-transformer",
					"origin/subclassing-notes",
					"upstream/2.0-development",
					"upstream/bump-config",
					"upstream/bump-xcconfigs",
					"upstream/github-reversible-transformer",
					"upstream/master",
					"upstream/mtlmanagedobject",
					"upstream/reversible-transformer",
					"upstream/subclassing-notes",
				]
				let expected = expectedNames.map { repo.remoteBranch(named: $0).value! }
				let actual = repo.remoteBranches().value!.sorted {
					return $0.longName.lexicographicallyPrecedes($1.longName)
				}
				expect(actual).to(equal(expected))
				expect(actual.map { $0.name }).to(equal(expectedNames))
			}
		}

		describe("Repository.localBranch(named:)") {
			it("should return the branch if it exists") {
				let result = Fixtures.simpleRepository.localBranch(named: "master")
				expect(result.value?.longName).to(equal("refs/heads/master"))
			}

			it("should error if the branch doesn't exists") {
				let result = Fixtures.simpleRepository.localBranch(named: "nonexistent")
				expect(result.error?.domain) == libGit2ErrorDomain
			}
		}

		describe("Repository.remoteBranch(named:)") {
			it("should return the branch if it exists") {
				let result = Fixtures.mantleRepository.remoteBranch(named: "upstream/master")
				expect(result.value?.longName).to(equal("refs/remotes/upstream/master"))
			}

			it("should error if the branch doesn't exists") {
				let result = Fixtures.simpleRepository.remoteBranch(named: "origin/nonexistent")
				expect(result.error?.domain) == libGit2ErrorDomain
			}
		}

		describe("Repository.fetch(_:)") {
			it("should fetch the data") {
				let repo = Fixtures.mantleRepository
				let remote = repo.remote(named: "origin").value!
				expect(repo.fetch(remote).value).toNot(beNil())
			}
		}

		describe("Repository.allTags()") {
			it("should return all the tags") {
				let repo = Fixtures.simpleRepository
				let expected = [
					repo.tag(named: "tag-1").value!,
					repo.tag(named: "tag-2").value!,
				]
				expect(repo.allTags().value).to(equal(expected))
			}
		}

		describe("Repository.tag(named:)") {
			it("should return the tag if it exists") {
				let result = Fixtures.simpleRepository.tag(named: "tag-2")
				expect(result.value?.longName).to(equal("refs/tags/tag-2"))
			}

			it("should error if the branch doesn't exists") {
				let result = Fixtures.simpleRepository.tag(named: "nonexistent")
				expect(result.error?.domain) == libGit2ErrorDomain
			}
		}

		describe("Repository.HEAD()") {
			it("should work when on a branch") {
				let result = Fixtures.simpleRepository.HEAD()
				expect(result.value?.longName).to(equal("refs/heads/master"))
				expect(result.value?.shortName).to(equal("master"))
				expect(result.value as? Branch).notTo(beNil())
			}

			it("should work when on a detached HEAD") {
				let result = Fixtures.detachedHeadRepository.HEAD()
				expect(result.value?.longName).to(equal("HEAD"))
				expect(result.value?.shortName).to(beNil())
				expect(result.value?.oid).to(equal(OID(string: "315b3f344221db91ddc54b269f3c9af422da0f2e")!))
				expect(result.value as? Reference).notTo(beNil())
			}
		}

		describe("Repository.setHEAD(OID)") {
			it("should set HEAD to the OID") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "315b3f344221db91ddc54b269f3c9af422da0f2e")!
				expect(repo.HEAD().value?.shortName).to(equal("master"))

				expect(repo.setHEAD(oid).error).to(beNil())
				let HEAD = repo.HEAD().value
				expect(HEAD?.longName).to(equal("HEAD"))
				expect(HEAD?.oid).to(equal(oid))

				expect(repo.setHEAD(repo.localBranch(named: "master").value!).error).to(beNil())
				expect(repo.HEAD().value?.shortName).to(equal("master"))
			}
		}

		describe("Repository.setHEAD(ReferenceType)") {
			it("should set HEAD to a branch") {
				let repo = Fixtures.detachedHeadRepository
				let oid = repo.HEAD().value!.oid
				expect(repo.HEAD().value?.longName).to(equal("HEAD"))

				let branch = repo.localBranch(named: "another-branch").value!
				expect(repo.setHEAD(branch).error).to(beNil())
				expect(repo.HEAD().value?.shortName).to(equal(branch.name))

				expect(repo.setHEAD(oid).error).to(beNil())
				expect(repo.HEAD().value?.longName).to(equal("HEAD"))
			}
		}

		describe("Repository.checkout()") {
			// We're not really equipped to test this yet. :(
		}

		describe("Repository.checkout(OID)") {
			it("should set HEAD") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "315b3f344221db91ddc54b269f3c9af422da0f2e")!
				expect(repo.HEAD().value?.shortName).to(equal("master"))

				expect(repo.checkout(oid, strategy: CheckoutStrategy.None).error).to(beNil())
				let HEAD = repo.HEAD().value
				expect(HEAD?.longName).to(equal("HEAD"))
				expect(HEAD?.oid).to(equal(oid))

				expect(repo.checkout(repo.localBranch(named: "master").value!, strategy: CheckoutStrategy.None).error).to(beNil())
				expect(repo.HEAD().value?.shortName).to(equal("master"))
			}

			it("should call block on progress") {
				let repo = Fixtures.simpleRepository
				let oid = OID(string: "315b3f344221db91ddc54b269f3c9af422da0f2e")!
				expect(repo.HEAD().value?.shortName).to(equal("master"))

				expect(repo.checkout(oid, strategy: .None, progress: { (_, completedSteps, totalSteps) -> Void in
					expect(completedSteps).to(beLessThanOrEqualTo(totalSteps))
				}).error).to(beNil())

				let HEAD = repo.HEAD().value
				expect(HEAD?.longName).to(equal("HEAD"))
				expect(HEAD?.oid).to(equal(oid))
			}
		}

		describe("Repository.checkout(ReferenceType)") {
			it("should set HEAD") {
				let repo = Fixtures.detachedHeadRepository
				let oid = repo.HEAD().value!.oid
				expect(repo.HEAD().value?.longName).to(equal("HEAD"))

				let branch = repo.localBranch(named: "another-branch").value!
				expect(repo.checkout(branch, strategy: CheckoutStrategy.None).error).to(beNil())
				expect(repo.HEAD().value?.shortName).to(equal(branch.name))

				expect(repo.checkout(oid, strategy: CheckoutStrategy.None).error).to(beNil())
				expect(repo.HEAD().value?.longName).to(equal("HEAD"))
			}
		}

		describe("Repository.allCommits(in:)") {
			it("should return all (9) commits") {
				let repo = Fixtures.simpleRepository
				let branches = repo.localBranches().value!
				let expectedCount = 9
				let expectedMessages: [String] = [
					"List branches in README\n",
					"Create a README\n",
					"Merge branch 'alphabetize'\n",
					"Alphabetize branches\n",
					"List new branches\n",
					"List branches in README\n",
					"Create a README\n",
					"List branches in README\n",
					"Create a README\n",
				]
				var commitMessages: [String] = []
				for branch in branches {
					for commit in repo.commits(in: branch) {
						commitMessages.append(commit.value!.message)
					}
				}
				expect(commitMessages.count).to(equal(expectedCount))
				expect(commitMessages).to(equal(expectedMessages))
			}
		}

		describe("Repository.add") {
			it("Should add the modification under a path") {
				let repo = Fixtures.simpleRepository
				let branch = repo.localBranch(named: "master").value!
				expect(repo.checkout(branch, strategy: CheckoutStrategy.None).error).to(beNil())

				// make a change to README
				let readmeURL = repo.directoryURL!.appendingPathComponent("README.md")
				let readmeData = try! Data(contentsOf: readmeURL)
				defer { try! readmeData.write(to: readmeURL) }

				try! "different".data(using: .utf8)?.write(to: readmeURL)

				let status = repo.status()
				expect(status.value?.count).to(equal(1))
				expect(status.value!.first!.status).to(equal(.workTreeModified))

				expect(repo.add(path: "README.md").error).to(beNil())

				let newStatus = repo.status()
				expect(newStatus.value?.count).to(equal(1))
				expect(newStatus.value!.first!.status).to(equal(.indexModified))
			}

			it("Should add an untracked file under a path") {
				let repo = Fixtures.simpleRepository
				let branch = repo.localBranch(named: "master").value!
				expect(repo.checkout(branch, strategy: CheckoutStrategy.None).error).to(beNil())

				// make a change to README
				let untrackedURL = repo.directoryURL!.appendingPathComponent("untracked")
				try! "different".data(using: .utf8)?.write(to: untrackedURL)
				defer { try! FileManager.default.removeItem(at: untrackedURL) }

				expect(repo.add(path: ".").error).to(beNil())

				let newStatus = repo.status()
				expect(newStatus.value?.count).to(equal(1))
				expect(newStatus.value!.first!.status).to(equal(.indexNew))
			}
		}

		describe("Repository.commit") {
			it("Should perform a simple commit with specified signature") {
				let repo = Fixtures.simpleRepository
				let branch = repo.localBranch(named: "master").value!
				expect(repo.checkout(branch, strategy: CheckoutStrategy.None).error).to(beNil())

				// make a change to README
				let untrackedURL = repo.directoryURL!.appendingPathComponent("untrackedtest")
				try! "different".data(using: .utf8)?.write(to: untrackedURL)

				expect(repo.add(path: ".").error).to(beNil())

				let signature = Signature(
					name: "swiftgit2",
					email: "foobar@example.com",
					time: Date(timeIntervalSince1970: 1525200858),
					timeZone: TimeZone(secondsFromGMT: 3600)!
				)
				let message = "Test Commit"
				expect(repo.commit(message: message, signature: signature).error).to(beNil())
				let updatedBranch = repo.localBranch(named: "master").value!
				expect(repo.commits(in: updatedBranch).next()?.value?.author).to(equal(signature))
				expect(repo.commits(in: updatedBranch).next()?.value?.committer).to(equal(signature))
				expect(repo.commits(in: updatedBranch).next()?.value?.message).to(equal("\(message)\n"))
				expect(repo.commits(in: updatedBranch).next()?.value?.oid.description)
					.to(equal("7d6b2d7492f29aee48022387f96dbfe996d435fe"))

				// should be clean now
				let newStatus = repo.status()
				expect(newStatus.value?.count).to(equal(0))
			}
		}

		describe("Repository.status") {
			it("Should accurately report status for repositories with no status") {
				let expectedCount = 0

				let repo = Fixtures.mantleRepository
				let branch = repo.localBranch(named: "master").value!
				expect(repo.checkout(branch, strategy: CheckoutStrategy.None).error).to(beNil())

				let status = repo.status()

				expect(status.value?.count).to(equal(expectedCount))
			}

			it("Should accurately report status for repositories with status") {
				let expectedCount = 6
				let expectedNewFilePaths = [
					"stage-file-1",
					"stage-file-2",
					"stage-file-3",
					"stage-file-4",
					"stage-file-5",
				]
				let expectedOldFilePaths = [
					"stage-file-1",
					"stage-file-2",
					"stage-file-3",
					"stage-file-4",
					"stage-file-5",
				]
				let expectedUntrackedFiles = [
					"unstaged-file",
				]

				let repoWithStatus = Fixtures.sharedInstance.repository(named: "repository-with-status")
				let branchWithStatus = repoWithStatus.localBranch(named: "master").value!
				expect(repoWithStatus.checkout(branchWithStatus, strategy: CheckoutStrategy.None).error).to(beNil())

				let statuses = repoWithStatus.status().value!

				var newFilePaths: [String] = []
				for status in statuses {
					if let path = status.headToIndex?.newFile?.path {
						newFilePaths.append(path)
					}
				}
				var oldFilePaths: [String] = []
				for status in statuses {
					if let path = status.headToIndex?.oldFile?.path {
						oldFilePaths.append(path)
					}
				}

				var newUntrackedFilePaths: [String] = []
				for status in statuses {
					if let path = status.indexToWorkDir?.newFile?.path {
						newUntrackedFilePaths.append(path)
					}
				}

				expect(statuses.count).to(equal(expectedCount))
				expect(newFilePaths).to(equal(expectedNewFilePaths))
				expect(oldFilePaths).to(equal(expectedOldFilePaths))
				expect(newUntrackedFilePaths).to(equal(expectedUntrackedFiles))
			}
		}

		describe("Repository.diff") {
			it("Should have accurate delta information") {
				let expectedCount = 13
				let expectedNewFilePaths = [
					".gitmodules",
					"Cartfile",
					"Cartfile.lock",
					"Cartfile.private",
					"Cartfile.resolved",
					"Carthage.checkout/Nimble",
					"Carthage.checkout/Quick",
					"Carthage.checkout/xcconfigs",
					"Carthage/Checkouts/Nimble",
					"Carthage/Checkouts/Quick",
					"Carthage/Checkouts/xcconfigs",
					"Mantle.xcodeproj/project.pbxproj",
					"Mantle.xcworkspace/contents.xcworkspacedata",
				]
				let expectedOldFilePaths = [
					".gitmodules",
					"Cartfile",
					"Cartfile.lock",
					"Cartfile.private",
					"Cartfile.resolved",
					"Carthage.checkout/Nimble",
					"Carthage.checkout/Quick",
					"Carthage.checkout/xcconfigs",
					"Carthage/Checkouts/Nimble",
					"Carthage/Checkouts/Quick",
					"Carthage/Checkouts/xcconfigs",
					"Mantle.xcodeproj/project.pbxproj",
					"Mantle.xcworkspace/contents.xcworkspacedata",
				]

				let repo = Fixtures.mantleRepository
				let branch = repo.localBranch(named: "master").value!
				expect(repo.checkout(branch, strategy: CheckoutStrategy.None).error).to(beNil())

				let head = repo.HEAD().value!
				let commit = repo.object(head.oid).value! as! Commit
				let diff = repo.diff(for: commit).value!

				let newFilePaths = diff.deltas.map { $0.newFile!.path }
				let oldFilePaths = diff.deltas.map { $0.oldFile!.path }

				expect(diff.deltas.count).to(equal(expectedCount))
				expect(newFilePaths).to(equal(expectedNewFilePaths))
				expect(oldFilePaths).to(equal(expectedOldFilePaths))
			}

			it("Should handle initial commit well") {
				let expectedCount = 2
				let expectedNewFilePaths = [
					".gitignore",
					"README.md",
				]
				let expectedOldFilePaths = [
					".gitignore",
					"README.md",
				]

				let repo = Fixtures.mantleRepository
				expect(repo.checkout(OID(string: "047b931bd7f5478340cef5885a6fff713005f4d6")!,
				                     strategy: CheckoutStrategy.None).error).to(beNil())
				let head = repo.HEAD().value!
				let initalCommit = repo.object(head.oid).value! as! Commit
				let diff = repo.diff(for: initalCommit).value!

				var newFilePaths: [String] = []
				for delta in diff.deltas {
					newFilePaths.append((delta.newFile?.path)!)
				}
				var oldFilePaths: [String] = []
				for delta in diff.deltas {
					oldFilePaths.append((delta.oldFile?.path)!)
				}

				expect(diff.deltas.count).to(equal(expectedCount))
				expect(newFilePaths).to(equal(expectedNewFilePaths))
				expect(oldFilePaths).to(equal(expectedOldFilePaths))
			}

			it("Should handle merge commits well") {
				let expectedCount = 20
				let expectedNewFilePaths = [
					"Mantle.xcodeproj/project.pbxproj",
					"Mantle/MTLModel+NSCoding.m",
					"Mantle/Mantle.h",
					"Mantle/NSArray+MTLHigherOrderAdditions.h",
					"Mantle/NSArray+MTLHigherOrderAdditions.m",
					"Mantle/NSArray+MTLManipulationAdditions.m",
					"Mantle/NSDictionary+MTLHigherOrderAdditions.h",
					"Mantle/NSDictionary+MTLHigherOrderAdditions.m",
					"Mantle/NSDictionary+MTLManipulationAdditions.m",
					"Mantle/NSNotificationCenter+MTLWeakReferenceAdditions.h",
					"Mantle/NSNotificationCenter+MTLWeakReferenceAdditions.m",
					"Mantle/NSOrderedSet+MTLHigherOrderAdditions.h",
					"Mantle/NSOrderedSet+MTLHigherOrderAdditions.m",
					"Mantle/NSSet+MTLHigherOrderAdditions.h",
					"Mantle/NSSet+MTLHigherOrderAdditions.m",
					"Mantle/NSValueTransformer+MTLPredefinedTransformerAdditions.m",
					"MantleTests/MTLHigherOrderAdditionsSpec.m",
					"MantleTests/MTLNotificationCenterAdditionsSpec.m",
					"MantleTests/MTLPredefinedTransformerAdditionsSpec.m",
					"README.md",
				]
				let expectedOldFilePaths = [
					"Mantle.xcodeproj/project.pbxproj",
					"Mantle/MTLModel+NSCoding.m",
					"Mantle/Mantle.h",
					"Mantle/NSArray+MTLHigherOrderAdditions.h",
					"Mantle/NSArray+MTLHigherOrderAdditions.m",
					"Mantle/NSArray+MTLManipulationAdditions.m",
					"Mantle/NSDictionary+MTLHigherOrderAdditions.h",
					"Mantle/NSDictionary+MTLHigherOrderAdditions.m",
					"Mantle/NSDictionary+MTLManipulationAdditions.m",
					"Mantle/NSNotificationCenter+MTLWeakReferenceAdditions.h",
					"Mantle/NSNotificationCenter+MTLWeakReferenceAdditions.m",
					"Mantle/NSOrderedSet+MTLHigherOrderAdditions.h",
					"Mantle/NSOrderedSet+MTLHigherOrderAdditions.m",
					"Mantle/NSSet+MTLHigherOrderAdditions.h",
					"Mantle/NSSet+MTLHigherOrderAdditions.m",
					"Mantle/NSValueTransformer+MTLPredefinedTransformerAdditions.m",
					"MantleTests/MTLHigherOrderAdditionsSpec.m",
					"MantleTests/MTLNotificationCenterAdditionsSpec.m",
					"MantleTests/MTLPredefinedTransformerAdditionsSpec.m",
					"README.md",
				]

				let repo = Fixtures.mantleRepository
				expect(repo.checkout(OID(string: "d0d9c13da5eb5f9e8cf2a9f1f6ca3bdbe975b57d")!,
				                     strategy: CheckoutStrategy.None).error).to(beNil())
				let head = repo.HEAD().value!
				let initalCommit = repo.object(head.oid).value! as! Commit
				let diff = repo.diff(for: initalCommit).value!

				var newFilePaths: [String] = []
				for delta in diff.deltas {
					newFilePaths.append((delta.newFile?.path)!)
				}
				var oldFilePaths: [String] = []
				for delta in diff.deltas {
					oldFilePaths.append((delta.oldFile?.path)!)
				}

				expect(diff.deltas.count).to(equal(expectedCount))
				expect(newFilePaths).to(equal(expectedNewFilePaths))
				expect(oldFilePaths).to(equal(expectedOldFilePaths))
			}
		}
	}

	func temporaryURL(forPurpose purpose: String) -> URL {
		let globallyUniqueString = ProcessInfo.processInfo.globallyUniqueString
		let path = "\(NSTemporaryDirectory())\(globallyUniqueString)_\(purpose)"
		return URL(fileURLWithPath: path)
	}
}
