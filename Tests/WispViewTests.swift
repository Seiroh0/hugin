import XCTest
import SwiftUI
@testable import Hugin

final class WispViewTests: XCTestCase {
    func testFarbeJeZustand() {
        XCTAssertEqual(WispView.color(for: .ruhe, actor: .local), HuginColor.glut)
        XCTAssertEqual(WispView.color(for: .uebergabe, actor: .local), HuginColor.frost)  // nach der Übergabe Frost
        XCTAssertEqual(WispView.color(for: .wartet, actor: .local), HuginColor.knochen)
        XCTAssertEqual(WispView.color(for: .stockt, actor: .local), HuginColor.rost)
        XCTAssertEqual(WispView.color(for: .ruhe, actor: .claude), HuginColor.frost)
    }
}
