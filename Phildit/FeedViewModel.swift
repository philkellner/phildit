import SwiftUI

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var subreddit = "popular"
    @Published var sort: SortMode = .hot
    @Published var searchQuery = ""

    private let client = RedditClient()
    private var after: String?
    private var canLoadMore = true

    func reload() async {
        posts = []; after = nil; canLoadMore = true
        await loadMore()
    }

    func loadMore() async {
        guard !isLoading, canLoadMore else { return }
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            let page = searchQuery.isEmpty
                ? try await client.posts(subreddit: subreddit, sort: sort, after: after)
                : try await client.search(searchQuery, after: after)
            let known = Set(posts.map(\.id))
            posts += page.posts.filter { !known.contains($0.id) }
            after = page.after
            canLoadMore = page.after != nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func openHome() async {
        subreddit = ""
        searchQuery = ""
        await reload()
    }

    func open(subreddit name: String) async {
        subreddit = name.replacingOccurrences(of: "r/", with: "").trimmingCharacters(in: .whitespaces)
        searchQuery = ""
        await reload()
    }
}
