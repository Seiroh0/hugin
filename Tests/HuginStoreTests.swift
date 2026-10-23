import XCTest
@testable import Hugin

final class HuginStoreTests: XCTestCase {
    func testSaveLoadUpsert() throws {
        let store = try HuginStore(inMemory: true)
        let id = UUID()
        try store.save(orderID: id, title: "Rechnungen zusammenfassen", actor: "lokal",
                      messages: [ChatMessage(role: .user, text: "hi")])
        XCTAssertEqual(store.load(orderID: id).count, 1)
        try store.save(orderID: id, title: "Rechnungen zusammenfassen", actor: "Claude",
                      messages: [
                        ChatMessage(role: .user, text: "hi"),
                        ChatMessage(role: .assistant, text: "moin")])
        let loaded = store.load(orderID: id)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.last?.text, "moin")
        XCTAssertEqual(store.load(orderID: UUID()), [])
    }

    func testListOrdersNeuesteZuerst() throws {
        let store = try HuginStore(inMemory: true)
        let alt = UUID(), neu = UUID()
        try store.save(orderID: alt, title: "Alter Auftrag", actor: "lokal",
                      messages: [ChatMessage(role: .user, text: "a")])
        try store.save(orderID: neu, title: "Neuer Auftrag", actor: "Claude",
                      messages: [ChatMessage(role: .user, text: "b")])
        let list = store.listOrders()
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list.first?.id, neu)
        XCTAssertEqual(list.first?.actor, "Claude")
        XCTAssertEqual(list.last?.title, "Alter Auftrag")
    }
}
