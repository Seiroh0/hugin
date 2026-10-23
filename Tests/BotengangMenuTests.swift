import XCTest
@testable import Hugin

final class BotengangMenuTests: XCTestCase {
    func testLabel() {
        XCTAssertEqual(BotengangMenu.label(for: .onDevice), "Im Haus")
        XCTAssertEqual(BotengangMenu.label(for: .auto), "Nach Bedarf")
        XCTAssertEqual(BotengangMenu.label(for: .claude), "Zu Claude")
    }
    func testSub() {
        XCTAssertEqual(BotengangMenu.sub(for: .onDevice), "nur iPad")
        XCTAssertEqual(BotengangMenu.sub(for: .auto), "lokal, sonst Claude")
        XCTAssertEqual(BotengangMenu.sub(for: .claude), "Cloud")
    }
    func testDescWortlaut() {
        XCTAssertEqual(BotengangMenu.desc(for: .onDevice),
            "Hugin bleibt bei dir: offline, privat, schnell. Keine Datei verlässt das iPad.")
        XCTAssertTrue(BotengangMenu.desc(for: .auto).contains("Jede Übergabe siehst du in der Flugbahn."))
        XCTAssertTrue(BotengangMenu.desc(for: .claude).contains("nur die nötigen Dateien verlassen das iPad."))
    }
    func testVorschlaegeNichtLeer() {
        XCTAssertEqual(StartView.vorschlaege.count, 3)
    }
}
