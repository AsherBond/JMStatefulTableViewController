//
//  JMStatefulState.swift
//  JMStatefulTableViewController
//
//  Created by Jake Marsh on 5/3/12.
//  Copyright © 2012 Jake Marsh. All rights reserved.
//

import Foundation

/// The possible states of a stateful table view controller.
public enum JMStatefulState: Equatable, Sendable {
    /// The table view is idle and showing content.
    case idle

    /// The table view is performing its initial load.
    case initialLoading

    /// The table view is refreshing via pull-to-refresh.
    case loadingFromPullToRefresh

    /// The table view is loading the next page (infinite scrolling).
    case loadingNextPage

    /// The table view has no content to display.
    case empty

    /// An error occurred while loading.
    case error(Error?)

    public static func == (lhs: JMStatefulState, rhs: JMStatefulState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.initialLoading, .initialLoading),
             (.loadingFromPullToRefresh, .loadingFromPullToRefresh),
             (.loadingNextPage, .loadingNextPage),
             (.empty, .empty):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}
