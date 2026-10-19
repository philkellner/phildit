import XCTest
@testable import Phildit

final class DecodingTests: XCTestCase {
    func testCommentWithEmptyRepliesAndMoreStub() throws {
        let json = """
        {"kind":"Listing","data":{"after":null,"children":[
          {"kind":"t1","data":{"id":"a","author":"x","body":"hi","score":3,"created_utc":1.0,"replies":""}},
          {"kind":"t1","data":{"id":"b","author":"y","body":"yo","score":1,"created_utc":2.0,
            "replies":{"kind":"Listing","data":{"after":null,"children":[
              {"kind":"t1","data":{"id":"c","author":"z","body":"re","score":1,"created_utc":3.0,"replies":""}},
              {"kind":"more","data":{"id":"m","count":5}}]}}}},
          {"kind":"more","data":{"id":"m2","count":9}}]}}
        """.data(using: .utf8)!
        let l = try JSONDecoder().decode(CommentListing.self, from: json)
        let cs = l.data.children.compactMap(\.comment)
        XCTAssertEqual(cs.map(\.id), ["a", "b"])
        XCTAssertEqual(cs[1].replies.map(\.id), ["c"])
    }
}

final class AuthDecodingTests: XCTestCase {
    func testTokenResponse() throws {
        let json = #"{"access_token":"a","token_type":"bearer","expires_in":86400,"refresh_token":"r","scope":"read"}"#.data(using: .utf8)!
        let t = try JSONDecoder().decode(TokenResponse.self, from: json)
        XCTAssertEqual(t.accessToken, "a")
        XCTAssertEqual(t.refreshToken, "r")
        XCTAssertEqual(t.expiresIn, 86400)
    }

    func testSubscriptionListing() throws {
        let json = #"{"kind":"Listing","data":{"after":null,"children":[{"kind":"t5","data":{"display_name":"swift"}}]}}"#.data(using: .utf8)!
        let l = try JSONDecoder().decode(Listing<Subreddit>.self, from: json)
        XCTAssertEqual(l.data.children.map(\.data.displayName), ["swift"])
    }
}
