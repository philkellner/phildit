import Foundation

struct RedditClient {
    enum RedditError: LocalizedError {
        case http(Int)
        var errorDescription: String? {
            switch self {
            case .http(429): return "Reddit is rate limiting requests. Try again shortly."
            case .http(let c): return "Reddit returned HTTP \(c)."
            }
        }
    }

    var session: URLSession = .shared
    // Reddit rejects generic user agents; identify the app.
    private let userAgent = "ios:com.philkellner.phildit:v1.0 (personal reader)"

    private func fetch<T: Decodable>(_ path: String, query: [URLQueryItem] = [], as type: T.Type) async throws -> T {
        var comps = URLComponents(string: "https://www.reddit.com" + path)!
        comps.queryItems = query + [URLQueryItem(name: "raw_json", value: "1")]
        var req = URLRequest(url: comps.url!)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RedditError.http(http.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func posts(subreddit: String, sort: SortMode, timeRange: String = "day", after: String? = nil) async throws -> (posts: [Post], after: String?) {
        var q = [URLQueryItem(name: "limit", value: "25")]
        if sort == .top { q.append(.init(name: "t", value: timeRange)) }
        if let after { q.append(.init(name: "after", value: after)) }
        let l = try await fetch("/r/\(subreddit)/\(sort.rawValue).json", query: q, as: Listing<Post>.self)
        return (l.data.children.map(\.data), l.data.after)
    }

    func search(_ query: String, after: String? = nil) async throws -> (posts: [Post], after: String?) {
        var q = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "25")]
        if let after { q.append(.init(name: "after", value: after)) }
        let l = try await fetch("/search.json", query: q, as: Listing<Post>.self)
        return (l.data.children.map(\.data), l.data.after)
    }

    func thread(postID: String) async throws -> (post: Post, comments: [Comment]) {
        let parts = try await fetch("/comments/\(postID).json", query: [.init(name: "limit", value: "200")], as: [ThreadPart].self)
        guard parts.count == 2, case .posts(let l) = parts[0], case .comments(let c) = parts[1],
              let post = l.data.children.first?.data else { throw URLError(.cannotParseResponse) }
        return (post, c.data.children.compactMap { $0.data.comment })
    }
}

/// /comments returns a 2-element array: [post listing, comment listing].
private enum ThreadPart: Decodable {
    case posts(Listing<Post>)
    case comments(Listing<CommentNode>)
    init(from decoder: Decoder) throws {
        if let p = try? Listing<Post>(from: decoder) { self = .posts(p) }
        else { self = .comments(try Listing<CommentNode>(from: decoder)) }
    }
}
