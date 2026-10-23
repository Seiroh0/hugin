import XCTest
@testable import Hugin

final class FakeProviderTests: XCTestCase {
    func testScriptUndProtokoll() async throws {
        let fake = FakeProvider(script: [.init(text: "ok", toolCalls: [])])
        let r = try await fake.respond(system: "sys", messages: [.user("hi")], tools: [])
        XCTAssertEqual(r.text, "ok")
        XCTAssertEqual(fake.received.count, 1)
        XCTAssertEqual(fake.received[0].system, "sys")
        XCTAssertEqual(fake.actor, .local)   // Default = Glut
    }
    func testWiederholtLetzteAntwort() async throws {
        let fake = FakeProvider(script: [.init(text: "", toolCalls: [.init(id: "1", name: "x", arguments: .object([:]))])])
        _ = try await fake.respond(system: "s", messages: [], tools: [])
        _ = try await fake.respond(system: "s", messages: [], tools: [])
        XCTAssertEqual(fake.received.count, 2)
    }
    func testActorKonfigurierbar() async throws {
        let fake = FakeProvider(script: [.init(text: "ok", toolCalls: [])], actor: .claude)
        _ = try await fake.respond(system: "s", messages: [], tools: [])
        XCTAssertEqual(fake.actor, .claude)
    }
}
