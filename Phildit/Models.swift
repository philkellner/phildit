import Foundation

struct Listing<T: Decodable>: Decodable {
    struct Data: Decodable {
        let children: [Child]
        let after: String?
    }
    struct Child: Decodable { let kind: String; let data: T }
    let data: Data
}

struct Post: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let subreddit: String
    let score: Int
    let numComments: Int
    let createdUtc: Double
    let selftext: String
    let url: String
    let domain: String
    let permalink: String
    let isSelf: Bool
    let over18: Bool
    let linkFlairText: String?
    let thumbnail: String?

    enum CodingKeys: String, CodingKey {
        case id, title, author, subreddit, score, selftext, url, domain, permalink, thumbnail
        case numComments = "num_comments"
        case createdUtc = "created_utc"
        case isSelf = "is_self"
        case over18 = "over_18"
        case linkFlairText = "link_flair_text"
    }

    var created: Date { Date(timeIntervalSince1970: createdUtc) }

    var imageURL: URL? {
        let lower = url.lowercased()
        guard ["jpg", "jpeg", "png", "gif", "webp"].contains(where: { lower.hasSuffix("." + $0) }) else { return nil }
        return URL(string: url)
    }
}

struct Comment: Identifiable, Hashable {
    let id: String
    let author: String
    let body: String
    let score: Int
    let createdUtc: Double
    var replies: [Comment]

    var created: Date { Date(timeIntervalSince1970: createdUtc) }
}

/// Reddit sends `replies` as "" when empty and as a Listing otherwise, and
/// mixes "more" stubs into children; decode leniently and keep only t1 nodes.
extension Comment: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, author, body, score, replies
        case createdUtc = "created_utc"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        author = (try? c.decode(String.self, forKey: .author)) ?? "[deleted]"
        body = (try? c.decode(String.self, forKey: .body)) ?? ""
        score = (try? c.decode(Int.self, forKey: .score)) ?? 0
        createdUtc = (try? c.decode(Double.self, forKey: .createdUtc)) ?? 0
        if let listing = try? c.decode(CommentListing.self, forKey: .replies) {
            replies = listing.data.children.compactMap(\.comment)
        } else {
            replies = []
        }
    }
}

/// A comment listing child: `kind` is a sibling of `data`; "more" stubs yield nil.
struct CommentNode: Decodable {
    let comment: Comment?
    enum CodingKeys: String, CodingKey { case kind, data }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        comment = kind == "t1" ? try c.decode(Comment.self, forKey: .data) : nil
    }
}

struct CommentListing: Decodable {
    struct Data: Decodable { let children: [CommentNode] }
    let data: Data
}

enum SortMode: String, CaseIterable, Identifiable {
    case hot, new, top, rising
    var id: String { rawValue }
}
