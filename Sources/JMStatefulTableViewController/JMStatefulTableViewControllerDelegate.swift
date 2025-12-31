//
//  JMStatefulTableViewControllerDelegate.swift
//  JMStatefulTableViewController
//
//  Created by Jake Marsh on 5/3/12.
//  Copyright © 2012 Jake Marsh. All rights reserved.
//

import Foundation

#if canImport(UIKit)
import UIKit

/// Result type for pull-to-refresh operations.
public struct JMPullToRefreshResult {
    /// Index paths of newly inserted rows (for "proper" pull-to-refresh behavior).
    public let insertedIndexPaths: [IndexPath]

    public init(insertedIndexPaths: [IndexPath] = []) {
        self.insertedIndexPaths = insertedIndexPaths
    }
}

/// Protocol for handling stateful table view events.
@MainActor
public protocol JMStatefulTableViewControllerDelegate: AnyObject {
    /// Called when the table view needs to perform its initial load.
    /// - Returns: Completes when loading is finished.
    func loadInitialContent() async throws

    /// Called when the user performs a pull-to-refresh gesture.
    /// - Returns: A result containing any newly inserted index paths.
    func loadFromPullToRefresh() async throws -> JMPullToRefreshResult

    /// Called when the user scrolls to the bottom and more content should load.
    /// - Returns: Completes when loading is finished.
    func loadNextPage() async throws

    /// Determines if there is more content available to load.
    /// - Returns: `true` if more content can be loaded, `false` otherwise.
    func canLoadNextPage() -> Bool

    /// Determines if pull-to-refresh should be enabled.
    /// - Returns: `true` to enable pull-to-refresh. Default is `true`.
    func shouldEnablePullToRefresh() -> Bool

    /// Determines if infinite scrolling should be enabled.
    /// - Returns: `true` to enable infinite scrolling. Default is `true`.
    func shouldEnableInfiniteScrolling() -> Bool

    /// Called when the state is about to change.
    /// - Parameters:
    ///   - oldState: The current state.
    ///   - newState: The state being transitioned to.
    func willTransition(from oldState: JMStatefulState, to newState: JMStatefulState)

    /// Called after the state has changed.
    /// - Parameter state: The new current state.
    func didTransition(to state: JMStatefulState)
}

// MARK: - Default Implementations

public extension JMStatefulTableViewControllerDelegate {
    func shouldEnablePullToRefresh() -> Bool { true }
    func shouldEnableInfiniteScrolling() -> Bool { true }
    func willTransition(from oldState: JMStatefulState, to newState: JMStatefulState) {}
    func didTransition(to state: JMStatefulState) {}
}

#endif
