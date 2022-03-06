//
//  FixturesSpec.swift
//  SwiftGit2
//
//  Created by Matt Diephouse on 11/16/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import Quick

class FixturesSpec: QuickSpec {
	override func spec() {
		beforeSuite {
			Fixtures.sharedInstance.setUp()
		}

		afterSuite {
			Fixtures.sharedInstance.tearDown()
		}
	}
}
