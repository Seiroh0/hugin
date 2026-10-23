import XCTest
@testable import Hugin

final class JSONValueTests: XCTestCase {
    func testRoundtrip() throws {
        let src: JSONValue = .object(["a": .number(1), "b": .string("x"),
            "c": .array([.bool(true), .null])])
        let back = try JSONValue.from(data: try src.data())
        XCTAssertEqual(back, src)
    }
    func testAccessors() {
        let v: JSONValue = .object(["n": .number(2.5), "s": .string("hi"), "b": .bool(true)])
        XCTAssertEqual(v["n"]?.doubleValue, 2.5)
        XCTAssertEqual(v["s"]?.stringValue, "hi")
        XCTAssertEqual(v["b"]?.boolValue, true)
        XCTAssertEqual(v["s"]?.boolValue, nil)
    }
}
