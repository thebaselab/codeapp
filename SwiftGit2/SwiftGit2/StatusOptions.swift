//
//  Copyright © 2020 GitHub, Inc. All rights reserved.
//

import Clibgit2
import Foundation

public struct StatusOptions: OptionSet {
	public let rawValue: UInt32
	
	public init(rawValue: UInt32) {
		self.rawValue = rawValue
	}
	
	public static let includeUntracked = StatusOptions(
		rawValue: GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue
	)
	public static let includeIgnored = StatusOptions(
		rawValue: GIT_STATUS_OPT_INCLUDE_IGNORED.rawValue
	)
	public static let includeUnmodified = StatusOptions(
		rawValue: GIT_STATUS_OPT_INCLUDE_UNMODIFIED.rawValue
	)
	public static let excludeSubmodules = StatusOptions(
		rawValue: GIT_STATUS_OPT_EXCLUDE_SUBMODULES.rawValue
	)
	public static let recurseUntrackedDirs = StatusOptions(
		rawValue: GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue
	)
	public static let disablePathSpecMatch = StatusOptions(
		rawValue: GIT_STATUS_OPT_DISABLE_PATHSPEC_MATCH.rawValue
	)
	public static let recurseIgnoredDirs = StatusOptions(
		rawValue: GIT_STATUS_OPT_RECURSE_IGNORED_DIRS.rawValue
	)
	public static let renamesHeadToIndex = StatusOptions(
		rawValue: GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX.rawValue
	)
	public static let renamesIndexToWorkDir = StatusOptions(
		rawValue: GIT_STATUS_OPT_RENAMES_INDEX_TO_WORKDIR.rawValue
	)
	public static let sortCasesSensitively = StatusOptions(
		rawValue: GIT_STATUS_OPT_SORT_CASE_SENSITIVELY.rawValue
	)
	public static let sortCasesInSensitively = StatusOptions(
		rawValue: GIT_STATUS_OPT_SORT_CASE_INSENSITIVELY.rawValue
	)
	public static let renamesFromRewrites = StatusOptions(
		rawValue: GIT_STATUS_OPT_RENAMES_FROM_REWRITES.rawValue
	)
	public static let noRefresh = StatusOptions(
		rawValue: GIT_STATUS_OPT_NO_REFRESH.rawValue
	)
	public static let updateIndex = StatusOptions(
		rawValue: GIT_STATUS_OPT_UPDATE_INDEX.rawValue
	)
	public static let includeUnreadable = StatusOptions(
		rawValue: GIT_STATUS_OPT_INCLUDE_UNREADABLE.rawValue
	)
	public static let includeUnreadableAsUntracked = StatusOptions(
		rawValue: GIT_STATUS_OPT_INCLUDE_UNREADABLE_AS_UNTRACKED.rawValue
	)
}
