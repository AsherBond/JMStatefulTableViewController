//
//  JMStatefulTableViewController.swift
//  JMStatefulTableViewController
//
//  Created by Jake Marsh on 5/3/12.
//  Copyright © 2012 Jake Marsh. All rights reserved.
//

#if canImport(UIKit)
import UIKit

/// A table view controller that manages loading states, pull-to-refresh, and infinite scrolling.
///
/// Subclass this and implement the `JMStatefulTableViewControllerDelegate` methods
/// to handle data loading.
///
/// ## States
/// - **idle**: Normal state, user can scroll and interact
/// - **initialLoading**: First load, shows `loadingView`
/// - **loadingFromPullToRefresh**: Pull-to-refresh in progress
/// - **loadingNextPage**: Infinite scrolling load in progress
/// - **empty**: No content, shows `emptyView`
/// - **error**: Error occurred, shows `errorView`
///
/// ## Usage
/// ```swift
/// class MyTableViewController: JMStatefulTableViewController {
///     var items: [Item] = []
///
///     override func loadInitialContent() async throws {
///         items = try await api.fetchItems()
///         tableView.reloadData()
///     }
///
///     override func loadFromPullToRefresh() async throws -> JMPullToRefreshResult {
///         let newItems = try await api.fetchNewerItems(than: items.first)
///         items.insert(contentsOf: newItems, at: 0)
///         let indexPaths = (0..<newItems.count).map { IndexPath(row: $0, section: 0) }
///         return JMPullToRefreshResult(insertedIndexPaths: indexPaths)
///     }
///
///     override func loadNextPage() async throws {
///         let moreItems = try await api.fetchOlderItems(than: items.last)
///         items.append(contentsOf: moreItems)
///         tableView.reloadData()
///     }
///
///     override func canLoadNextPage() -> Bool {
///         return hasMorePages
///     }
/// }
/// ```
@MainActor
open class JMStatefulTableViewController: UITableViewController, JMStatefulTableViewControllerDelegate {

    // MARK: - State

    /// The current state of the table view controller.
    public private(set) var statefulState: JMStatefulState = .idle {
        willSet {
            statefulDelegate?.willTransition(from: statefulState, to: newValue)
        }
        didSet {
            handleStateChange()
            statefulDelegate?.didTransition(to: statefulState)
        }
    }

    // MARK: - Views

    /// View displayed during initial loading. Default is a centered activity indicator.
    public var loadingView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        return view
    }()

    /// View displayed when the table has no content.
    public var emptyView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "No Content"
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        return view
    }()

    /// View displayed when an error occurs.
    public var errorView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "Error Loading Content"
        label.textColor = .systemRed
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        return view
    }()

    // MARK: - Delegate

    /// The delegate that handles loading operations. Defaults to `self`.
    public weak var statefulDelegate: JMStatefulTableViewControllerDelegate?

    // MARK: - Private Properties

    private var hasAddedPullToRefreshControl = false
    private var loadingTask: Task<Void, Never>?

    // MARK: - Initialization

    public override init(style: UITableView.Style) {
        super.init(style: style)
        statefulDelegate = self
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        statefulDelegate = self
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        statefulDelegate = self
    }

    deinit {
        loadingTask?.cancel()
    }

    // MARK: - View Lifecycle

    open override func viewDidLoad() {
        super.viewDidLoad()
        setupInfiniteScrolling()
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !hasAddedPullToRefreshControl {
            setupPullToRefresh()
        }

        if totalNumberOfRows() == 0 && statefulState == .idle {
            loadFirstPage()
        }
    }

    // MARK: - Setup

    private func setupPullToRefresh() {
        guard statefulDelegate?.shouldEnablePullToRefresh() ?? true else { return }

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        refreshControl = refresh
        hasAddedPullToRefreshControl = true
    }

    private func setupInfiniteScrolling() {
        // Using scroll view delegate for infinite scrolling
    }

    // MARK: - Loading Methods

    /// Triggers a refresh. If content exists, performs pull-to-refresh; otherwise, loads initial content.
    public func loadNewer() {
        if totalNumberOfRows() == 0 {
            loadFirstPage()
        } else {
            loadFromPullToRefreshInternal()
        }
    }

    /// Forces a reload from the initial state.
    public func forceReload() {
        loadFirstPage()
    }

    private func loadFirstPage() {
        guard statefulState != .initialLoading else { return }
        guard totalNumberOfRows() == 0 else { return }

        statefulState = .initialLoading
        tableView.reloadData()

        loadingTask?.cancel()
        loadingTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                try await self.statefulDelegate?.loadInitialContent()

                if self.totalNumberOfRows() > 0 {
                    self.statefulState = .idle
                } else {
                    self.statefulState = .empty
                }
            } catch {
                if !Task.isCancelled {
                    self.statefulState = .error(error)
                }
            }
        }
    }

    @objc private func handlePullToRefresh() {
        loadFromPullToRefreshInternal()
    }

    private func loadFromPullToRefreshInternal() {
        guard statefulState != .loadingFromPullToRefresh else { return }

        statefulState = .loadingFromPullToRefresh

        loadingTask?.cancel()
        loadingTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                let result = try await self.statefulDelegate?.loadFromPullToRefresh() ?? JMPullToRefreshResult()

                if !result.insertedIndexPaths.isEmpty {
                    // Calculate height of new rows for "proper" pull-to-refresh
                    let totalHeight = self.cumulativeHeight(for: result.insertedIndexPaths)
                    let offset = self.refreshControl?.frame.height ?? 0

                    self.tableView.contentInset = UIEdgeInsets(top: offset, left: 0, bottom: 0, right: 0)
                    self.tableView.reloadData()

                    if self.tableView.contentOffset.y == 0 {
                        self.tableView.contentOffset = CGPoint(x: 0, y: totalHeight - 60)
                    } else {
                        self.tableView.contentOffset = CGPoint(x: 0, y: self.tableView.contentOffset.y + totalHeight)
                    }
                } else {
                    self.tableView.reloadData()
                }

                self.statefulState = .idle
                self.refreshControl?.endRefreshing()

            } catch {
                if !Task.isCancelled {
                    self.statefulState = .idle
                    self.refreshControl?.endRefreshing()
                }
            }
        }
    }

    private func loadNextPageInternal() {
        guard statefulState != .loadingNextPage else { return }
        guard statefulDelegate?.canLoadNextPage() ?? false else { return }

        statefulState = .loadingNextPage

        loadingTask?.cancel()
        loadingTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                try await self.statefulDelegate?.loadNextPage()
                self.tableView.reloadData()

                if self.totalNumberOfRows() > 0 {
                    self.statefulState = .idle
                } else {
                    self.statefulState = .empty
                }
            } catch {
                if !Task.isCancelled {
                    self.statefulState = .idle
                }
            }
        }
    }

    // MARK: - Scroll View Delegate (Infinite Scrolling)

    open override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)

        guard statefulDelegate?.shouldEnableInfiniteScrolling() ?? true else { return }
        guard statefulState == .idle else { return }

        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.height

        // Trigger loading when user scrolls near the bottom
        if offsetY > contentHeight - frameHeight - 100 {
            if statefulDelegate?.canLoadNextPage() ?? false {
                loadNextPageInternal()
            }
        }
    }

    // MARK: - State Handling

    private func handleStateChange() {
        switch statefulState {
        case .idle:
            tableView.backgroundView = nil
            tableView.separatorStyle = .singleLine
            tableView.isScrollEnabled = true
            tableView.tableHeaderView?.isHidden = false
            tableView.tableFooterView?.isHidden = false

        case .initialLoading:
            tableView.backgroundView = loadingView
            tableView.separatorStyle = .none
            tableView.isScrollEnabled = false
            tableView.tableHeaderView?.isHidden = true
            tableView.tableFooterView?.isHidden = true

        case .loadingFromPullToRefresh, .loadingNextPage:
            // Keep current state, just show loading indicator
            break

        case .empty:
            tableView.backgroundView = emptyView
            tableView.separatorStyle = .none
            tableView.isScrollEnabled = false
            tableView.tableHeaderView?.isHidden = true
            tableView.tableFooterView?.isHidden = true

        case .error:
            tableView.backgroundView = errorView
            tableView.separatorStyle = .none
            tableView.isScrollEnabled = false
            tableView.tableHeaderView?.isHidden = true
            tableView.tableFooterView?.isHidden = true
        }

        tableView.reloadData()
    }

    // MARK: - Helpers

    /// Returns the total number of rows across all sections.
    public func totalNumberOfRows() -> Int {
        let sections = numberOfSections(in: tableView)
        var total = 0
        for section in 0..<sections {
            total += tableView(tableView, numberOfRowsInSection: section)
        }
        return total
    }

    private func cumulativeHeight(for indexPaths: [IndexPath]) -> CGFloat {
        indexPaths.reduce(0) { total, indexPath in
            total + tableView(tableView, heightForRowAt: indexPath)
        }
    }

    // MARK: - JMStatefulTableViewControllerDelegate (Override in subclass)

    open func loadInitialContent() async throws {
        assertionFailure("loadInitialContent() must be implemented by subclass")
    }

    open func loadFromPullToRefresh() async throws -> JMPullToRefreshResult {
        assertionFailure("loadFromPullToRefresh() must be implemented by subclass")
        return JMPullToRefreshResult()
    }

    open func loadNextPage() async throws {
        assertionFailure("loadNextPage() must be implemented by subclass")
    }

    open func canLoadNextPage() -> Bool {
        assertionFailure("canLoadNextPage() must be implemented by subclass")
        return false
    }

    open func shouldEnablePullToRefresh() -> Bool { true }
    open func shouldEnableInfiniteScrolling() -> Bool { true }
    open func willTransition(from oldState: JMStatefulState, to newState: JMStatefulState) {}
    open func didTransition(to state: JMStatefulState) {}
}

#endif
