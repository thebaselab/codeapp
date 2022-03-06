//
//  RemotesSpec.swift
//  SwiftGit2
//
//  Created by Matt Diephouse on 1/2/15.
//  Copyright (c) 2015 GitHub, Inc. All rights reserved.
//

import SwiftGit2
import Nimble
import Quick
import Clibgit2

private extension Repository {
	func withGitRemote<T>(named name: String, transform: (OpaquePointer) -> T) -> T {
		let repository = self.pointer

		var pointer: OpaquePointer? = nil
		git_remote_lookup(&pointer, repository, name)
		let result = transform(pointer!)
		git_remote_free(pointer)

		return result
	}
}

class RemoteSpec: FixturesSpec {
	override func spec() {
		describe("Remote(pointer)") {
			it("should initialize its properties") {
				let repo = Fixtures.mantleRepository
				let remote = repo.withGitRemote(named: "upstream") { Remote($0) }

				expect(remote.name).to(equal("upstream"))
				expect(remote.URL).to(equal("git@github.com:Mantle/Mantle.git"))
			}
		}

		describe("==(Remote, Remote)") {
			it("should be true with equal objects") {
				let repo = Fixtures.mantleRepository
				let remote1 = repo.withGitRemote(named: "upstream") { Remote($0) }
				let remote2 = remote1
				expect(remote1).to(equal(remote2))
			}

			it("should be false with unequal objcets") {
				let repo = Fixtures.mantleRepository
				let origin = repo.withGitRemote(named: "origin") { Remote($0) }
				let upstream = repo.withGitRemote(named: "upstream") { Remote($0) }
				expect(origin).notTo(equal(upstream))
			}
		}

		describe("Remote.hashValue") {
			it("should be equal with equal objcets") {
				let repo = Fixtures.mantleRepository
				let remote1 = repo.withGitRemote(named: "upstream") { Remote($0) }
				let remote2 = remote1
				expect(remote1.hashValue).to(equal(remote2.hashValue))
			}
		}
	}
}
