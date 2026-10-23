import XCTest
@testable import Hugin

final class SecurityStoreTests: XCTestCase {
    var store: SecurityStore!
    var defaults: UserDefaults!
    var tmp: URL!

    override func setUp() {
        defaults = UserDefaults(suiteName: UUID().uuidString)
        store = SecurityStore(defaults: defaults)
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: tmp) }

    func testGrantRoundtrip() throws {
        let grant = try store.addGrant(url: tmp)
        XCTAssertEqual(grant.name, tmp.lastPathComponent)
        let loaded = store.loadGrants()
        XCTAssertEqual(loaded.grants.first?.name, grant.name)
        XCTAssertEqual(loaded.skipped, 0)
    }
    func testKaputtesBookmarkWirdUebersprungen() throws {
        _ = try store.addGrant(url: tmp)
        defaults.set(try JSONEncoder().encode([BookmarkRecord(id: UUID(), name: "Kaputt", data: Data([1, 2, 3]))]),
                                              forKey: SecurityStore.storageKey)
        let (grants, skipped) = store.loadGrants()
        XCTAssertTrue(grants.isEmpty)
        XCTAssertEqual(skipped, 1)
    }
    func testDoppelteNamenVerboten() throws {
        _ = try store.addGrant(url: tmp)
        XCTAssertThrowsError(try store.addGrant(url: tmp))
    }
    func testKeyRoundtrip() throws {
        XCTAssertNil(store.loadKey())
        try store.saveKey("sk-test-123")
        XCTAssertEqual(store.loadKey(), "sk-test-123")
        store.removeKey()
        XCTAssertNil(store.loadKey())
    }
}
