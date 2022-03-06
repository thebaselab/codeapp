//
//  ReferencesSpec.swift
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
	func withGitReference<T>(named name: String, transform: (OpaquePointer) -> T) -> T {
		let repository = self.pointer

		var pointer: OpaquePointer? = nil
		git_reference_lookup(&pointer, repository, name)
		let result = transform(pointer!)
		git_reference_free(pointer)

		return result
	}
}

class ReferenceSpec: FixturesSpec {
	override func spec() {
		describe("Reference(pointer)") {
			it("should initialize its properties") {
				let repo = Fixtures.simpleRepository
				let ref = repo.withGitReference(named: "refs/heads/master") { Reference($0) }
				expect(ref.longName).to(equal("refs/heads/master"))
				expect(ref.shortName).to(equal("master"))
				expect(ref.oid).to(equal(OID(string: "c4ed03a6b7d7ce837d31d83757febbe84dd465fd")!))
			}
		}

		describe("==(Reference, Reference)") {
			it("should be true with equal references") {
				let repo = Fixtures.simpleRepository
				let ref1 = repo.withGitReference(named: "refs/heads/master") { Reference($0) }
				let ref2 = repo.withGitReference(named: "refs/heads/master") { Reference($0) }
				expect(ref1).to(equal(ref2))
			}

			it("should be false with unequal references") {
				let repo = Fixtures.simpleRepository
				let ref1 = repo.withGitReference(named: "refs/heads/master") { Reference($0) }
				let ref2 = repo.withGitReference(named: "refs/heads/another-branch") { Reference($0) }
				expect(ref1).notTo(equal(ref2))
			}
		}

		describe("Reference.hashValue") {
			it("should be equal with equal references") {
				let repo = Fixtures.simpleRepository
				let ref1 = repo.withGitReference(named: "refs/heads/master") { Reference($0) }
				let ref2 = repo.withGitReference(named: "refs/heads/master") { Reference($0) }
				expect(ref1.hashValue).to(equal(ref2.hashValue))
			}
		}
	}
}

class BranchSpec: QuickSpec {
	override func spec() {
		describe("Branch(pointer)") {
			it("should initialize its properties") {
				let repo = Fixtures.mantleRepository
				let branch = repo.withGitReference(named: "refs/heads/master") { Branch($0)! }
				expect(branch.longName).to(equal("refs/heads/master"))
				expect(branch.name).to(equal("master"))
				expect(branch.shortName).to(equal(branch.name))
				expect(branch.commit.oid).to(equal(OID(string: "f797bd4837b61d37847a4833024aab268599a681")!))
				expect(branch.oid).to(equal(branch.commit.oid))
				expect(branch.isLocal).to(beTrue())
				expect(branch.isRemote).to(beFalse())
			}

			it("should work with symoblic refs") {
				let repo = Fixtures.mantleRepository
				let branch = repo.withGitReference(named: "refs/remotes/origin/HEAD") { Branch($0)! }
				expect(branch.longName).to(equal("refs/remotes/origin/HEAD"))
				expect(branch.name).to(equal("origin/HEAD"))
				expect(branch.shortName).to(equal(branch.name))
				expect(branch.commit.oid).to(equal(OID(string: "f797bd4837b61d37847a4833024aab268599a681")!))
				expect(branch.oid).to(equal(branch.commit.oid))
				expect(branch.isLocal).to(beFalse())
				expect(branch.isRemote).to(beTrue())
			}
		}

		describe("==(Branch, Branch)") {
			it("should be true with equal branches") {
				let repo = Fixtures.simpleRepository
				let branch1 = repo.withGitReference(named: "refs/heads/master") { Branch($0)! }
				let branch2 = repo.withGitReference(named: "refs/heads/master") { Branch($0)! }
				expect(branch1).to(equal(branch2))
			}

			it("should be false with unequal branches") {
				let repo = Fixtures.simpleRepository
				let branch1 = repo.withGitReference(named: "refs/heads/master") { Branch($0)! }
				let branch2 = repo.withGitReference(named: "refs/heads/another-branch") { Branch($0)! }
				expect(branch1).notTo(equal(branch2))
			}
		}

		describe("Branch.hashValue") {
			it("should be equal with equal references") {
				let repo = Fixtures.simpleRepository
				let branch1 = repo.withGitReference(named: "refs/heads/master") { Branch($0)! }
				let branch2 = repo.withGitReference(named: "refs/heads/master") { Branch($0)! }
				expect(branch1.hashValue).to(equal(branch2.hashValue))
			}
		}
	}
}

class TagReferenceSpec: QuickSpec {
	override func spec() {
		describe("TagReference(pointer)") {
			it("should work with an annotated tag") {
				let repo = Fixtures.simpleRepository
				let tag = repo.withGitReference(named: "refs/tags/tag-2") { TagReference($0)! }
				expect(tag.longName).to(equal("refs/tags/tag-2"))
				expect(tag.name).to(equal("tag-2"))
				expect(tag.shortName).to(equal(tag.name))
				expect(tag.oid).to(equal(OID(string: "24e1e40ee77525d9e279f079f9906ad6d98c8940")!))
			}

			it("should work with a lightweight tag") {
				let repo = Fixtures.mantleRepository
				let tag = repo.withGitReference(named: "refs/tags/1.5.4") { TagReference($0)! }
				expect(tag.longName).to(equal("refs/tags/1.5.4"))
				expect(tag.name).to(equal("1.5.4"))
				expect(tag.shortName).to(equal(tag.name))
				expect(tag.oid).to(equal(OID(string: "d9dc95002cfbf3929d2b70d2c8a77e6bf5b1b88a")!))
			}

			it("should return nil if not a tag") {
				let repo = Fixtures.simpleRepository
				let tag = repo.withGitReference(named: "refs/heads/master") { TagReference($0) }
				expect(tag).to(beNil())
			}
		}

		describe("==(TagReference, TagReference)") {
			it("should be true with equal tag references") {
				let repo = Fixtures.simpleRepository
				let tag1 = repo.withGitReference(named: "refs/tags/tag-2") { TagReference($0)! }
				let tag2 = repo.withGitReference(named: "refs/tags/tag-2") { TagReference($0)! }
				expect(tag1).to(equal(tag2))
			}

			it("should be false with unequal tag references") {
				let repo = Fixtures.simpleRepository
				let tag1 = repo.withGitReference(named: "refs/tags/tag-1") { TagReference($0)! }
				let tag2 = repo.withGitReference(named: "refs/tags/tag-2") { TagReference($0)! }
				expect(tag1).notTo(equal(tag2))
			}
		}

		describe("TagReference.hashValue") {
			it("should be equal with equal references") {
				let repo = Fixtures.simpleRepository
				let tag1 = repo.withGitReference(named: "refs/tags/tag-2") { TagReference($0)! }
				let tag2 = repo.withGitReference(named: "refs/tags/tag-2") { TagReference($0)! }
				expect(tag1.hashValue).to(equal(tag2.hashValue))
			}
		}
	}
}
