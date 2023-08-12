//
//  RepositoryState.swift
//  
//
//  Created by Ken Chung on 12/08/2023.
//

import Clibgit2
import Foundation

public struct RepositoryState: OptionSet {
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let none = RepositoryState(
        rawValue: GIT_REPOSITORY_STATE_NONE.rawValue
    )
    public static let merge = RepositoryState(
        rawValue: GIT_REPOSITORY_STATE_MERGE.rawValue
    )
    public static let revert = RepositoryState(
        rawValue: GIT_REPOSITORY_STATE_REVERT.rawValue
    )
    public static let revertSequence = RepositoryState(
        rawValue: GIT_REPOSITORY_STATE_REVERT_SEQUENCE.rawValue
    )
    public static let cherryPick = RepositoryState(
        rawValue: GIT_REPOSITORY_STATE_CHERRYPICK.rawValue
    )
    public static let cherryPickSequence = RepositoryState(
        rawValue: GIT_REPOSITORY_STATE_CHERRYPICK_SEQUENCE.rawValue
    )
    public static let bisect = RepositoryState(
        rawValue: GIT_REPOSITORY_STATE_BISECT.rawValue
    )
    public static let rebase = RepositoryState(
        rawValue: GIT_REPOSITORY_STATE_REBASE.rawValue
    )
    public static let rebaseInteractive = RepositoryState(
        rawValue: GIT_REPOSITORY_STATE_REBASE_INTERACTIVE.rawValue
    )
    public static let rebaseMerge = RepositoryState(
        rawValue: GIT_REPOSITORY_STATE_REBASE_MERGE.rawValue
    )
    public static let applyMailbox = RepositoryState(
        rawValue: GIT_REPOSITORY_STATE_APPLY_MAILBOX.rawValue
    )
    public static let applyMailboxOrRebase = RepositoryState(
        rawValue: GIT_REPOSITORY_STATE_APPLY_MAILBOX_OR_REBASE.rawValue
    )
}
