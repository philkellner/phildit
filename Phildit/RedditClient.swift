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
    static let userAgent = "ios:com.philkellner.phildit:v1.0 (personal reader)"

    private func fetch<T: Decodable>(_ path: String, query: [URLQueryItem] = [], as type: T.Type) async throws -> T {
        // Logged in: authenticated API host with a bearer token; otherwise the public site.
        let token = try await AuthManager.shared.validToken()
        let host = token == nil ? "https://www.reddit.com" : "https://oauth.reddit.com"
        var comps = URLComponents(string: host + path)!
        comps.queryItems = query + [URLQueryItem(name: "raw_json", value: "1")]
        var req = URLRequest(url: comps.url!)
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
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
        // An empty subreddit means the logged-in home feed ("best" is Reddit's name for hot).
        let path = subreddit.isEmpty
            ? "/\(sort == .hot ? "best" : sort.rawValue).json"
            : "/r/\(subreddit)/\(sort.rawValue).json"
        let l = try await fetch(path, query: q, as: Listing<Post>.self)
        return (l.data.children.map(\.data), l.data.after)
    }

    func me() async throws -> String {
        struct Me: Decodable { let name: String }
        return try await fetch("/api/v1/me", as: Me.self).name
    }

    func subscriptions() async throws -> [String] {
        var names: [String] = [], after: String?
        repeat {
            var q = [URLQueryItem(name: "limit", value: "100")]
            if let after { q.append(.init(name: "after", value: after)) }
            let l = try await fetch("/subreddits/mine/subscriber", query: q, as: Listing<Subreddit>.self)
            names += l.data.children.map(\.data.displayName)
            after = l.data.after
        } while after != nil && names.count < 1000
        return names.sorted { $0.lowercased() < $1.lowercased() }
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
        return (post, c.data.children.compactMap(\.comment))
    }
}

/// /comments returns a 2-element array: [post listing, comment listing].
private enum ThreadPart: Decodable {
    case posts(Listing<Post>)
    case comments(CommentListing)
    init(from decoder: Decoder) throws {
        if let p = try? Listing<Post>(from: decoder) { self = .posts(p) }
        else { self = .comments(try CommentListing(from: decoder)) }
    }
}
