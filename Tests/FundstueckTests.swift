import XCTest
@testable import Hugin

final class FundstueckTests: XCTestCase {
    func testLetzteGeleseneDatei() {
        let cards: [ActionCard] = [
            .init(id: UUID(), kind: .search, actor: .local, title: "Suche", detail: "3 Treffer", durationMS: 10, createdAt: Date()),
            .init(id: UUID(), kind: .read, actor: .local, title: "Datei gelesen", detail: "Doku/Strom.pdf", durationMS: 20, createdAt: Date()),
            .init(id: UUID(), kind: .read, actor: .claude, title: "Datei gelesen", detail: "Doku/Handy.pdf", durationMS: 30, createdAt: Date())
        ]
        let msg = ChatMessage(role: .assistant, text: "ok", cards: cards)
        XCTAssertEqual(FundstueckView.latestRead(in: [msg]), "Handy.pdf")   // neueste, Anzeige nur Dateiname
    }
    func testFindingsSammeln() {
        let f1 = Finding(id: UUID(), name: "Strom", value: "64,20 €", actor: .local, createdAt: Date())
        let f2 = Finding(id: UUID(), name: "Handy", value: "24,99 €", actor: .claude, createdAt: Date())
        let m1 = ChatMessage(role: .assistant, text: "a", findings: [f1])
        let m2 = ChatMessage(role: .assistant, text: "b", findings: [f2])
        XCTAssertEqual(FundstueckView.findings(in: [m1, m2]).map(\.name), ["Strom", "Handy"])
    }
    func testOhneReadKarte() {
        let msg = ChatMessage(role: .assistant, text: "nichts gelesen",
                              cards: [.init(id: UUID(), kind: .search, actor: .local,
                                            title: "Suche", detail: "0 Treffer",
                                            durationMS: 5, createdAt: Date())])
        XCTAssertNil(FundstueckView.latestRead(in: [msg]))
    }
}
