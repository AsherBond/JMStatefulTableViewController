//
//  JMStatefulList.swift
//  JMStatefulTableViewController
//
//  SwiftUI implementation of stateful list with loading states.
//

import SwiftUI

/// A SwiftUI list that manages loading states, pull-to-refresh, and pagination.
///
/// ## Usage
/// ```swift
/// struct ContentView: View {
///     @StateObject private var viewModel = ItemsViewModel()
///
///     var body: some View {
///         JMStatefulList(
///             state: viewModel.state,
///             loadInitial: { try await viewModel.loadInitial() },
///             loadMore: viewModel.hasMore ? { try await viewModel.loadMore() } : nil,
///             refresh: { try await viewModel.refresh() }
///         ) {
///             ForEach(viewModel.items) { item in
///                 ItemRow(item: item)
///             }
///         }
///     }
/// }
/// ```
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct JMStatefulList<Content: View>: View {
    /// The current loading state.
    public let state: JMStatefulListState

    /// Closure called for initial content load.
    public let loadInitial: () async throws -> Void

    /// Optional closure for loading more content. `nil` disables pagination.
    public let loadMore: (() async throws -> Void)?

    /// Optional closure for pull-to-refresh. `nil` disables refresh.
    public let refresh: (() async throws -> Void)?

    /// The list content.
    @ViewBuilder public let content: () -> Content

    /// Custom view for loading state.
    public var loadingView: AnyView?

    /// Custom view for empty state.
    public var emptyView: AnyView?

    /// Custom view for error state.
    public var errorView: ((Error) -> AnyView)?

    @State private var isLoadingMore = false
    @State private var isRefreshing = false
    @State private var loadInitialTask: Task<Void, Never>?

    public init(
        state: JMStatefulListState,
        loadInitial: @escaping () async throws -> Void,
        loadMore: (() async throws -> Void)? = nil,
        refresh: (() async throws -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.state = state
        self.loadInitial = loadInitial
        self.loadMore = loadMore
        self.refresh = refresh
        self.content = content
    }

    public var body: some View {
        Group {
            switch state {
            case .idle:
                listContent

            case .loading:
                if let loadingView = loadingView {
                    loadingView
                } else {
                    defaultLoadingView
                }

            case .empty:
                if let emptyView = emptyView {
                    emptyView
                } else {
                    defaultEmptyView
                }

            case .error(let error):
                if let errorView = errorView {
                    errorView(error)
                } else {
                    defaultErrorView(error)
                }
            }
        }
        .task {
            if case .loading = state {
                do {
                    try await loadInitial()
                } catch {
                    // Error handling is done through state binding
                }
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if let refresh = refresh {
            List {
                content()
                loadMoreSection
            }
            .refreshable {
                isRefreshing = true
                try? await refresh()
                isRefreshing = false
            }
        } else {
            List {
                content()
                loadMoreSection
            }
        }
    }

    @ViewBuilder
    private var loadMoreSection: some View {
        if let loadMore = loadMore {
            Section {
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            Task {
                                isLoadingMore = true
                                try? await loadMore()
                                isLoadingMore = false
                            }
                        }
                }
            }
        }
    }

    private var defaultLoadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var defaultEmptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Content")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func defaultErrorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Error Loading Content")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                Task {
                    try? await loadInitial()
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - View Modifiers

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension JMStatefulList {
    /// Sets a custom loading view.
    public func loadingView<V: View>(@ViewBuilder _ view: @escaping () -> V) -> Self {
        var copy = self
        copy.loadingView = AnyView(view())
        return copy
    }

    /// Sets a custom empty view.
    public func emptyView<V: View>(@ViewBuilder _ view: @escaping () -> V) -> Self {
        var copy = self
        copy.emptyView = AnyView(view())
        return copy
    }

    /// Sets a custom error view.
    public func errorView<V: View>(@ViewBuilder _ view: @escaping (Error) -> V) -> Self {
        var copy = self
        copy.errorView = { error in AnyView(view(error)) }
        return copy
    }
}

// MARK: - State

/// The state of a stateful list.
public enum JMStatefulListState: Equatable {
    /// The list is displaying content normally.
    case idle

    /// The list is performing initial load.
    case loading

    /// The list has no content.
    case empty

    /// An error occurred.
    case error(Error)

    public static func == (lhs: JMStatefulListState, rhs: JMStatefulListState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.empty, .empty):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}

// MARK: - Observable State Manager

/// An observable object for managing stateful list state.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
public class JMStatefulListStateManager: ObservableObject {
    @Published public var state: JMStatefulListState = .loading

    public init() {}

    /// Transitions to idle state.
    public func setIdle() {
        state = .idle
    }

    /// Transitions to loading state.
    public func setLoading() {
        state = .loading
    }

    /// Transitions to empty state.
    public func setEmpty() {
        state = .empty
    }

    /// Transitions to error state.
    public func setError(_ error: Error) {
        state = .error(error)
    }
}
