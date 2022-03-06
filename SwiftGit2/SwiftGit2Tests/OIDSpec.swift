//
//  OIDSpec.swift
//  SwiftGit2
//
//  Created by Matt Diephouse on 11/17/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import SwiftGit2
import Nimble
import Quick

class OIDSpec: QuickSpec {
	override func spec() {
		describe("OID(string:)") {
			it("should be nil if string is too short") {
				expect(OID(string: "123456789012345678901234567890123456789")).to(beNil())
			}

			it("should be nil if string is too long") {
				expect(OID(string: "12345678901234567890123456789012345678901")).to(beNil())
			}

			it("should not be nil if string is just right") {
				expect(OID(string: "1234567890123456789012345678ABCDEFabcdef")).notTo(beNil())
			}

			it("should be nil with non-hex characters") {
				expect(OID(string: "123456789012345678901234567890123456789j")).to(beNil())
			}
		}

		describe("OID(oid)") {
			it("should equal an OID with the same git_oid") {
				let oid = OID(string: "1234567890123456789012345678901234567890")!
				expect(OID(oid.oid)).to(equal(oid))
			}
		}

		describe("OID.description") {
			it("should return the SHA") {
				let SHA = "1234567890123456789012345678901234567890"
				let oid = OID(string: SHA)!
				expect(oid.description).to(equal(SHA))
			}
		}

		describe("==(OID, OID)") {
			it("should be equal when identical") {
				let SHA = "1234567890123456789012345678901234567890"
				let oid1 = OID(string: SHA)!
				let oid2 = OID(string: SHA)!
				expect(oid1).to(equal(oid2))
			}

			it("should be not equal when different") {
				let oid1 = OID(string: "1234567890123456789012345678901234567890")!
				let oid2 = OID(string: "0000000000000000000000000000000000000000")!
				expect(oid1).notTo(equal(oid2))
			}
		}

		describe("OID.hashValue") {
			it("should be equal when OIDs are equal") {
				let SHA = "1234567890123456789012345678901234567890"
				let oid1 = OID(string: SHA)!
				let oid2 = OID(string: SHA)!
				expect(oid1.hashValue).to(equal(oid2.hashValue))
			}
		}
	}
}
