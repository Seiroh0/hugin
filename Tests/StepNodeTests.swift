import XCTest
@testable import Hugin

final class StepNodeTests: XCTestCase {
    func testLabelJeKnoten() {
        XCTAssertEqual(StepNode.label(for: .search), "SUCHEN")
        XCTAssertEqual(StepNode.label(for: .read), "LESEN")
        XCTAssertEqual(StepNode.label(for: .write), "SCHREIBEN")
        XCTAssertEqual(StepNode.label(for: .rename), "UMBENENNEN")
        XCTAssertEqual(StepNode.label(for: .move), "VERSCHIEBEN")
        XCTAssertEqual(StepNode.label(for: .handover), "ÜBERGABE")
        XCTAssertEqual(StepNode.label(for: .backup), "SICHERUNG")
        XCTAssertEqual(StepNode.label(for: .error), "FEHLER")
        XCTAssertEqual(StepNode.label(for: .list), "AUFLISTEN")
    }
    func testDauerFormat() {
        XCTAssertEqual(StepNode.formatDuration(nil), "")
        XCTAssertEqual(StepNode.formatDuration(400), "0,4 s")
        XCTAssertEqual(StepNode.formatDuration(1_100), "1,1 s")
        XCTAssertEqual(StepNode.formatDuration(59_999), "59,9 s")   // kein Rundungs-Grenzbruch
        XCTAssertEqual(StepNode.formatDuration(60_000), "1:00")
        XCTAssertEqual(StepNode.formatDuration(75_000), "1:15")
    }
    func testHintLabel() {
        XCTAssertEqual(StepNode.label(for: .hint), "HINWEIS")
    }
}
