# JMStatefulTableViewController

A stateful table view controller for iOS that manages loading states, pull-to-refresh, and infinite scrolling. Now includes SwiftUI support!

## Features

- **Loading States**: Automatic management of idle, loading, empty, and error states
- **Pull-to-Refresh**: Built-in support using native `UIRefreshControl`
- **Infinite Scrolling**: Automatic pagination when scrolling near the bottom
- **SwiftUI Support**: `JMStatefulList` component with the same functionality
- **Modern Swift**: Async/await API, @MainActor support, Sendable conformance
- **Customizable Views**: Easily replace loading, empty, and error views
- **State Callbacks**: Delegate methods for state transitions

## Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 5.9+
- Xcode 15+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jakemarsh/JMStatefulTableViewController.git", from: "2.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter the repository URL.

## Usage

### UIKit - JMStatefulTableViewController

Subclass `JMStatefulTableViewController` and implement the required loading methods:

```swift
class MyTableViewController: JMStatefulTableViewController {
    var items: [Item] = []
    var hasMorePages = true

    // MARK: - Data Source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row].title
        return cell
    }

    // MARK: - Loading Methods

    override func loadInitialContent() async throws {
        items = try await api.fetchItems()
        tableView.reloadData()
    }

    override func loadFromPullToRefresh() async throws -> JMPullToRefreshResult {
        let newItems = try await api.fetchNewerItems(than: items.first)
        items.insert(contentsOf: newItems, at: 0)

        // Return inserted index paths for smooth animation
        let indexPaths = (0..<newItems.count).map { IndexPath(row: $0, section: 0) }
        return JMPullToRefreshResult(insertedIndexPaths: indexPaths)
    }

    override func loadNextPage() async throws {
        let moreItems = try await api.fetchOlderItems(than: items.last)
        items.append(contentsOf: moreItems)
        hasMorePages = !moreItems.isEmpty
        tableView.reloadData()
    }

    override func canLoadNextPage() -> Bool {
        hasMorePages
    }
}
```

### SwiftUI - JMStatefulList

Use `JMStatefulList` for SwiftUI projects:

```swift
struct ContentView: View {
    @StateObject private var viewModel = ItemsViewModel()

    var body: some View {
        JMStatefulList(
            state: viewModel.state,
            loadInitial: { try await viewModel.loadInitial() },
            loadMore: viewModel.hasMore ? { try await viewModel.loadMore() } : nil,
            refresh: { try await viewModel.refresh() }
        ) {
            ForEach(viewModel.items) { item in
                ItemRow(item: item)
            }
        }
    }
}

@MainActor
class ItemsViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var state: JMStatefulListState = .loading
    var hasMore = true

    func loadInitial() async throws {
        items = try await api.fetchItems()
        state = items.isEmpty ? .empty : .idle
    }

    func loadMore() async throws {
        let moreItems = try await api.fetchOlderItems(than: items.last)
        items.append(contentsOf: moreItems)
        hasMore = !moreItems.isEmpty
    }

    func refresh() async throws {
        let newItems = try await api.fetchNewerItems(than: items.first)
        items.insert(contentsOf: newItems, at: 0)
    }
}
```

### Using JMStatefulListStateManager

For more convenient state management:

```swift
@MainActor
class ItemsViewModel: ObservableObject {
    @Published var items: [Item] = []
    let stateManager = JMStatefulListStateManager()
    var hasMore = true

    func loadInitial() async throws {
        do {
            items = try await api.fetchItems()
            if items.isEmpty {
                stateManager.setEmpty()
            } else {
                stateManager.setIdle()
            }
        } catch {
            stateManager.setError(error)
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ItemsViewModel()

    var body: some View {
        JMStatefulList(
            state: viewModel.stateManager.state,
            loadInitial: { try await viewModel.loadInitial() },
            loadMore: viewModel.hasMore ? { try await viewModel.loadMore() } : nil
        ) {
            ForEach(viewModel.items) { item in
                ItemRow(item: item)
            }
        }
    }
}
```

## States

Both UIKit and SwiftUI implementations support similar states:

### UIKit States (JMStatefulState)

| State | Description |
|-------|-------------|
| `idle` | Normal state, user can scroll and interact |
| `initialLoading` | First load, shows `loadingView` |
| `loadingFromPullToRefresh` | Pull-to-refresh in progress |
| `loadingNextPage` | Infinite scrolling load in progress |
| `empty` | No content, shows `emptyView` |
| `error(Error?)` | Error occurred, shows `errorView` |

### SwiftUI States (JMStatefulListState)

| State | Description |
|-------|-------------|
| `idle` | Normal state, content is visible |
| `loading` | Initial load in progress |
| `empty` | No content to display |
| `error(Error)` | Error occurred |

## Customizing Views

### UIKit

```swift
class MyTableViewController: JMStatefulTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Custom loading view
        let loadingView = UIView()
        let spinner = UIActivityIndicatorView(style: .large)
        // ... configure spinner
        loadingView.addSubview(spinner)
        self.loadingView = loadingView

        // Custom empty view
        let emptyView = UIView()
        let label = UILabel()
        label.text = "No items yet"
        emptyView.addSubview(label)
        self.emptyView = emptyView

        // Custom error view
        let errorView = UIView()
        // ... configure error view with retry button
        self.errorView = errorView
    }
}
```

### SwiftUI

```swift
JMStatefulList(
    state: viewModel.state,
    loadInitial: { try await viewModel.loadInitial() }
) {
    ForEach(viewModel.items) { item in
        ItemRow(item: item)
    }
}
.loadingView {
    VStack {
        ProgressView()
        Text("Loading...")
    }
}
.emptyView {
    VStack {
        Image(systemName: "tray")
            .font(.largeTitle)
        Text("No items yet")
    }
}
.errorView { error in
    VStack {
        Text("Error: \(error.localizedDescription)")
        Button("Retry") {
            Task { try await viewModel.loadInitial() }
        }
    }
}
```

## Configuration

### Disabling Features (UIKit)

```swift
class MyTableViewController: JMStatefulTableViewController {
    // Disable pull-to-refresh
    override func shouldEnablePullToRefresh() -> Bool {
        false
    }

    // Disable infinite scrolling
    override func shouldEnableInfiniteScrolling() -> Bool {
        false
    }
}
```

### State Transition Callbacks (UIKit)

```swift
class MyTableViewController: JMStatefulTableViewController {
    override func willTransition(from oldState: JMStatefulState, to newState: JMStatefulState) {
        print("Transitioning from \(oldState) to \(newState)")
    }

    override func didTransition(to state: JMStatefulState) {
        print("Now in state: \(state)")
    }
}
```

## Migration from v1.x

Version 2.0 is a complete rewrite in Swift with modern APIs:

### Key Changes

1. **Async/await**: All loading methods now use `async throws` instead of callbacks
2. **Native refresh control**: Uses `UIRefreshControl` instead of SVPullToRefresh
3. **Swift Package Manager**: Primary distribution method
4. **SwiftUI support**: New `JMStatefulList` component

### Migration Steps

1. Replace callback-based loading with async methods:

```swift
// Before (v1.x)
- (void)loadInitialContentWithCompletion:(void(^)(NSError *))completion {
    [self.api fetchItemsWithCompletion:^(NSArray *items, NSError *error) {
        self.items = items;
        completion(error);
    }];
}

// After (v2.0)
override func loadInitialContent() async throws {
    items = try await api.fetchItems()
    tableView.reloadData()
}
```

2. Update state checking:

```swift
// Before
if (self.statefulState == JMStatefulTableViewControllerStateIdle) { ... }

// After
if statefulState == .idle { ... }
```

3. Replace delegate with override methods (or keep using delegate if preferred)

## License

MIT License. See [LICENSE](LICENSE) for details.

## Author

Jake Marsh ([@jakemarsh](https://github.com/jakemarsh))
