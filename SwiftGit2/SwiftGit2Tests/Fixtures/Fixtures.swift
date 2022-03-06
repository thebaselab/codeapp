//
//  Fixtures.swift
//  SwiftGit2
//
//  Created by Matt Diephouse on 11/16/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import SwiftGit2
import ZipArchive

final class Fixtures {

	// MARK: Lifecycle

	class var sharedInstance: Fixtures {
		enum Singleton {
			static let instance = Fixtures()
		}
		return Singleton.instance
	}

	init() {
		directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
			.appendingPathComponent("org.libgit2.SwiftGit2")
			.appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
	}

	// MARK: - Setup and Teardown

	let directoryURL: URL

	func setUp() {
		try! FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

		#if os(OSX)
			let platform = "OSX"
		#else
			let platform = "iOS"
		#endif
		let bundleIdentifier = String(format: "org.libgit2.SwiftGit2-%@Tests", arguments: [platform])
		let bundle = Bundle(identifier: bundleIdentifier)!
		let zipURLs = bundle.urls(forResourcesWithExtension: "zip", subdirectory: nil)!

		for URL in zipURLs {
			SSZipArchive.unzipFile(atPath: URL.path, toDestination: directoryURL.path)
		}
	}

	func tearDown() {
		try! FileManager.default.removeItem(at: directoryURL)
	}

	// MARK: - Helpers

	func repository(named name: String) -> Repository {
		let url = directoryURL.appendingPathComponent(name, isDirectory: true)
		return Repository.at(url).value!
	}

	// MARK: - The Fixtures

	class var detachedHeadRepository: Repository {
		return Fixtures.sharedInstance.repository(named: "detached-head")
	}

	class var simpleRepository: Repository {
		return Fixtures.sharedInstance.repository(named: "simple-repository")
	}

	class var mantleRepository: Repository {
		return Fixtures.sharedInstance.repository(named: "Mantle")
	}
}
