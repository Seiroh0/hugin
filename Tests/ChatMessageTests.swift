import XCTest
@testable import Hugin

final class ChatMessageTests: XCTestCase {
    func testCodableRoundtrip() throws {
        let m = ChatMessage(role: .assistant, text: "Fertig",
            cards: [ActionCard(id: UUID(), kind: .read, actor: .local, title: "gelesen",
                               detail: "Doku/a.md", durationMS: 900, createdAt: Date())],
            findings: [Finding(id: UUID(), name: "Strom", value: "64,20 €", actor: .local, createdAt: Date())])
        let data = try JSONEncoder().encode(m)
        let back = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(back.text, "Fertig")
        XCTAssertEqual(back.cards.first?.kind, .read)
        XCTAssertEqual(back.cards.first?.actor, .local)
        XCTAssertEqual(back.cards.first?.durationMS, 900)
        XCTAssertEqual(back.findings.first?.name, "Strom")
        XCTAssertEqual(back.findings.first?.actor, .local)
    }
    func testDefaultsSindLeer() {
        let m = ChatMessage(role: .user, text: "hi")
        XCTAssertTrue(m.cards.isEmpty)
        XCTAssertTrue(m.findings.isEmpty)
        XCTAssertNil(ActionCard(id: UUID(), kind: .hint, actor: nil, title: "x", detail: "", durationMS: nil, createdAt: Date()).actor)
    }
}
