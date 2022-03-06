//
//  Copyright © 2020 GitHub, Inc. All rights reserved.
//

import Clibgit2
import Foundation

public struct MergeAnalysisResult: OptionSet {
	public let rawValue: UInt32
	
	public init(rawValue: UInt32) {
		self.rawValue = rawValue
	}
	
	public static let none = MergeAnalysisResult(
		rawValue: GIT_MERGE_ANALYSIS_NONE.rawValue
	)
	public static let normal = MergeAnalysisResult(
		rawValue: GIT_MERGE_ANALYSIS_NORMAL.rawValue
	)
	public static let upToDate = MergeAnalysisResult(
		rawValue: GIT_MERGE_ANALYSIS_UP_TO_DATE.rawValue
	)
	public static let unborn = MergeAnalysisResult(
		rawValue: GIT_MERGE_ANALYSIS_UNBORN.rawValue
	)
	public static let fastForward = MergeAnalysisResult(
		rawValue: GIT_MERGE_ANALYSIS_FASTFORWARD.rawValue
	)
}
