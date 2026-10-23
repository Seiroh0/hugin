import XCTest
@testable import Hugin

final class DiffViewTests: XCTestCase {
    func testNeuOhneAlt() {
        let lines = DiffView.compute(old: nil, new: "a\nb")
        XCTAssertEqual(lines.map(\.sign), ["+", "+"])
        XCTAssertEqual(lines.map(\.text), ["a", "b"])
    }
    func testIdentisch() {
        let lines = DiffView.compute(old: "a\nb", new: "a\nb")
        XCTAssertTrue(lines.filter { $0.sign == "+" || $0.sign == "-" }.isEmpty)
        XCTAssertEqual(lines.map(\.text), ["a", "b"])   // Kontextzeilen ohne Vorzeichen
    }
    func testMittlereAenderung() {
        let lines = DiffView.compute(old: "Kopf\nalt\nFuß", new: "Kopf\nneu\nFuß")
        XCTAssertEqual(lines.map(\.sign), [" ", "-", "+", " "])
        XCTAssertEqual(lines.filter { $0.sign == "-" }.map(\.text), ["alt"])
        XCTAssertEqual(lines.filter { $0.sign == "+" }.map(\.text), ["neu"])
    }
    func testEinzeiligUndSuffix() {
        XCTAssertEqual(DiffView.compute(old: "x", new: "y").map(\.sign), ["-", "+"])
        let lines = DiffView.compute(old: "a", new: "a\nb")
        XCTAssertEqual(lines.map(\.sign), [" ", "+"])
    }
    func testRiesenInputWirdGekappt() {
        let big = (0..<50_000).map(String.init).joined(separator: "\n")
        let lines = DiffView.compute(old: nil, new: big)
        XCTAssertEqual(lines.count, 301)                      // 300 Zeilen + Kürzungs-Marker
        XCTAssertTrue(lines.last?.text.contains("gekürzt") == true)
        let longLine = String(repeating: "x", count: 50_000)
        XCTAssertEqual(DiffView.compute(old: nil, new: longLine).first?.text.count, 1_002)
    }
}
