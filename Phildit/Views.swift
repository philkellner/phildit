import SwiftUI

struct RootView: View {
    @StateObject private var vm = FeedViewModel()
    @State private var subField = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.posts) { post in
                    NavigationLink(value: post) { PostRow(post: post) }
                        .task { if post.id == vm.posts.last?.id { await vm.loadMore() } }
                }
                if vm.isLoading { ProgressView().frame(maxWidth: .infinity) }
                if let e = vm.error {
                    VStack(spacing: 8) {
                        Text(e).foregroundStyle(.red).multilineTextAlignment(.center)
                        Button("Retry") { Task { await vm.loadMore() } }
                    }.frame(maxWidth: .infinity)
                }
            }
            .listStyle(.plain)
            .navigationTitle(vm.searchQuery.isEmpty ? "r/\(vm.subreddit)" : "Search")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Post.self) { ThreadView(post: $0) }
            .refreshable { await vm.reload() }
            .searchable(text: $subField, prompt: "Subreddit or search")
            .onSubmit(of: .search) {
                let text = subField.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { return }
                Task {
                    if text.hasPrefix("r/") || !text.contains(" ") && text.range(of: "^[A-Za-z0-9_]+$", options: .regularExpression) != nil {
                        await vm.open(subreddit: text)
                    } else {
                        vm.searchQuery = text
                        await vm.reload()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Sort", selection: $vm.sort) {
                        ForEach(SortMode.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: vm.sort) { _, _ in Task { await vm.reload() } }
                }
            }
        }
        .task { await vm.reload() }
    }
}

struct PostRow: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("r/\(post.subreddit) · u/\(post.author) · \(post.created.formatted(.relative(presentation: .named)))")
                .font(.caption).foregroundStyle(.secondary)
            Text(post.title).font(.headline)
            if let flair = post.linkFlairText {
                Text(flair).font(.caption2).padding(.horizontal, 8).padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            if let url = post.imageURL, !post.over18 {
                AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Color.clear.frame(height: 1) }
                    .frame(maxHeight: 360).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HStack(spacing: 12) {
                Label("\(post.score)", systemImage: "arrow.up")
                Label("\(post.numComments)", systemImage: "bubble.left")
                if !post.isSelf { Text(post.domain).lineLimit(1) }
                if post.over18 { Text("NSFW").foregroundStyle(.red) }
            }.font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ThreadView: View {
    let post: Post
    @State private var comments: [Comment] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            Section {
                PostRow(post: post)
                if !post.selftext.isEmpty { Text(.init(post.selftext)) }
                if !post.isSelf, let url = URL(string: post.url) {
                    Link(post.domain, destination: url)
                }
            }
            Section("\(post.numComments) comments") {
                if loading { ProgressView().frame(maxWidth: .infinity) }
                if let error { Text(error).foregroundStyle(.red) }
                ForEach(comments) { CommentView(comment: $0, depth: 0) }
            }
        }
        .listStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do { comments = try await RedditClient().thread(postID: post.id).comments }
            catch { self.error = error.localizedDescription }
            loading = false
        }
    }
}

struct CommentView: View {
    let comment: Comment
    let depth: Int
    @State private var collapsed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { withAnimation { collapsed.toggle() } } label: {
                Text("u/\(comment.author) · ▲ \(comment.score) · \(comment.created.formatted(.relative(presentation: .named)))")
                    .font(.caption).foregroundStyle(.secondary)
            }.buttonStyle(.plain)
            if !collapsed {
                Text(.init(comment.body)).font(.subheadline)
                ForEach(comment.replies) { CommentView(comment: $0, depth: depth + 1) }
            }
        }
        .padding(.leading, depth == 0 ? 0 : 10)
        .overlay(alignment: .leading) {
            if depth > 0 { Rectangle().fill(.quaternary).frame(width: 2) }
        }
    }
}
