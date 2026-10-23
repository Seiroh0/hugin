import XCTest
@testable import Hugin

final class LaunchSequenceTests: XCTestCase {
    func testPhasenZeitfenster() {
        XCTAssertEqual(LaunchSequenceView.phase(at: 0), .funke)
        XCTAssertEqual(LaunchSequenceView.phase(at: 0.2), .staebe)
        XCTAssertEqual(LaunchSequenceView.phase(at: 0.6), .spur)
        XCTAssertEqual(LaunchSequenceView.phase(at: 0.9), .aufflammen)
        XCTAssertEqual(LaunchSequenceView.phase(at: 1.2), .ui)
    }
    func testPhasenGrenzenExakt() {
        // Grenzen gehören der späteren Phase an (>=): 0,12 / 0,42 / 0,82 / 1,0
        XCTAssertEqual(LaunchSequenceView.phase(at: 0.12), .staebe)
        XCTAssertEqual(LaunchSequenceView.phase(at: 0.42), .spur)
        XCTAssertEqual(LaunchSequenceView.phase(at: 0.82), .aufflammen)
        XCTAssertEqual(LaunchSequenceView.phase(at: 1.0), .ui)
    }
    func testReduceMotionSpringtZurUI() {
        XCTAssertEqual(LaunchSequenceView.phase(at: 0, reduceMotion: true), .ui)
    }
}
