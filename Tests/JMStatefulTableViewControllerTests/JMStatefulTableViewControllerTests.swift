import XCTest
@testable import JMStatefulTableViewController

// MARK: - State Tests

final class JMStatefulStateTests: XCTestCase {
    func testStateEquality() {
        XCTAssertEqual(JMStatefulState.idle, JMStatefulState.idle)
        XCTAssertEqual(JMStatefulState.initialLoading, JMStatefulState.initialLoading)
        XCTAssertEqual(JMStatefulState.loadingFromPullToRefresh, JMStatefulState.loadingFromPullToRefresh)
        XCTAssertEqual(JMStatefulState.loadingNextPage, JMStatefulState.loadingNextPage)
        XCTAssertEqual(JMStatefulState.empty, JMStatefulState.empty)
    }

    func testErrorStateEquality() {
        let error1 = NSError(domain: "test", code: 1)
        let error2 = NSError(domain: "test", code: 2)

        // Error states are considered equal regardless of the specific error
        XCTAssertEqual(JMStatefulState.error(error1), JMStatefulState.error(error2))
        XCTAssertEqual(JMStatefulState.error(nil), JMStatefulState.error(error1))
    }

    func testStateInequality() {
        XCTAssertNotEqual(JMStatefulState.idle, JMStatefulState.empty)
        XCTAssertNotEqual(JMStatefulState.initialLoading, JMStatefulState.loadingNextPage)
        XCTAssertNotEqual(JMStatefulState.idle, JMStatefulState.error(nil))
    }
}

// MARK: - SwiftUI State Tests

final class JMStatefulListStateTests: XCTestCase {
    func testStateEquality() {
        XCTAssertEqual(JMStatefulListState.idle, JMStatefulListState.idle)
        XCTAssertEqual(JMStatefulListState.loading, JMStatefulListState.loading)
        XCTAssertEqual(JMStatefulListState.empty, JMStatefulListState.empty)
    }

    func testErrorStateEquality() {
        let error1 = NSError(domain: "test", code: 1)
        let error2 = NSError(domain: "test", code: 2)

        XCTAssertEqual(JMStatefulListState.error(error1), JMStatefulListState.error(error2))
    }

    func testStateInequality() {
        XCTAssertNotEqual(JMStatefulListState.idle, JMStatefulListState.loading)
        XCTAssertNotEqual(JMStatefulListState.empty, JMStatefulListState.idle)
    }
}

// MARK: - State Manager Tests

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
final class JMStatefulListStateManagerTests: XCTestCase {
    func testInitialState() {
        let manager = JMStatefulListStateManager()
        XCTAssertEqual(manager.state, .loading)
    }

    func testSetIdle() {
        let manager = JMStatefulListStateManager()
        manager.setIdle()
        XCTAssertEqual(manager.state, .idle)
    }

    func testSetLoading() {
        let manager = JMStatefulListStateManager()
        manager.setIdle()
        manager.setLoading()
        XCTAssertEqual(manager.state, .loading)
    }

    func testSetEmpty() {
        let manager = JMStatefulListStateManager()
        manager.setEmpty()
        XCTAssertEqual(manager.state, .empty)
    }

    func testSetError() {
        let manager = JMStatefulListStateManager()
        let error = NSError(domain: "test", code: 1)
        manager.setError(error)

        if case .error = manager.state {
            // Success
        } else {
            XCTFail("Expected error state")
        }
    }
}

// MARK: - UIKit Tests (iOS only)

#if canImport(UIKit)
import UIKit

final class JMPullToRefreshResultTests: XCTestCase {
    func testDefaultInitializer() {
        let result = JMPullToRefreshResult()
        XCTAssertTrue(result.insertedIndexPaths.isEmpty)
    }

    func testWithIndexPaths() {
        let indexPaths = [
            IndexPath(row: 0, section: 0),
            IndexPath(row: 1, section: 0),
            IndexPath(row: 2, section: 0)
        ]
        let result = JMPullToRefreshResult(insertedIndexPaths: indexPaths)
        XCTAssertEqual(result.insertedIndexPaths.count, 3)
        XCTAssertEqual(result.insertedIndexPaths[0].row, 0)
        XCTAssertEqual(result.insertedIndexPaths[1].row, 1)
        XCTAssertEqual(result.insertedIndexPaths[2].row, 2)
    }
}

@MainActor
final class JMStatefulTableViewControllerTests: XCTestCase {
    func testInitialState() {
        let vc = TestStatefulTableViewController(style: .plain)
        XCTAssertEqual(vc.statefulState, .idle)
    }

    func testTotalNumberOfRowsEmpty() {
        let vc = TestStatefulTableViewController(style: .plain)
        _ = vc.view // Load view
        XCTAssertEqual(vc.totalNumberOfRows(), 0)
    }

    func testTotalNumberOfRowsWithData() {
        let vc = TestStatefulTableViewController(style: .plain)
        vc.items = ["A", "B", "C"]
        _ = vc.view // Load view
        XCTAssertEqual(vc.totalNumberOfRows(), 3)
    }

    func testDefaultViews() {
        let vc = TestStatefulTableViewController(style: .plain)
        XCTAssertNotNil(vc.loadingView)
        XCTAssertNotNil(vc.emptyView)
        XCTAssertNotNil(vc.errorView)
    }

    func testCustomViews() {
        let vc = TestStatefulTableViewController(style: .plain)

        let customLoading = UIView()
        let customEmpty = UIView()
        let customError = UIView()

        vc.loadingView = customLoading
        vc.emptyView = customEmpty
        vc.errorView = customError

        XCTAssertEqual(vc.loadingView, customLoading)
        XCTAssertEqual(vc.emptyView, customEmpty)
        XCTAssertEqual(vc.errorView, customError)
    }
}

// MARK: - Test Helper

@MainActor
class TestStatefulTableViewController: JMStatefulTableViewController {
    var items: [String] = []
    var shouldLoadMore = false
    var loadInitialCalled = false
    var loadMoreCalled = false
    var refreshCalled = false

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = items[indexPath.row]
        return cell
    }

    override func loadInitialContent() async throws {
        loadInitialCalled = true
    }

    override func loadFromPullToRefresh() async throws -> JMPullToRefreshResult {
        refreshCalled = true
        return JMPullToRefreshResult()
    }

    override func loadNextPage() async throws {
        loadMoreCalled = true
    }

    override func canLoadNextPage() -> Bool {
        shouldLoadMore
    }
}

#endif
