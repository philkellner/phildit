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
        let l = try JSONDecoder().decode(Listing<CommentNode>.self, from: json)
        let cs = l.data.children.compactMap { $0.data.comment }
        XCTAssertEqual(cs.map(\.id), ["a", "b"])
        XCTAssertEqual(cs[1].replies.map(\.id), ["c"])
    }
}
