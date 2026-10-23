import XCTest
import SwiftUI
import UIKit
@testable import Hugin

final class HuginThemeTests: XCTestCase {
    func testFarbenExakt() {
        // Hex-Werte wortwörtlich aus dem Design pinieren (fängt Tippfehler wie #EE9A30 ab)
        assertRGB(HuginColor.glut, red: 0xEE, green: 0x9A, blue: 0x3C)
        assertRGB(HuginColor.frost, red: 0xBE, green: 0xE4, blue: 0xF0)
        assertRGB(HuginColor.rost, red: 0xE0, green: 0x61, blue: 0x3F)
        assertRGB(HuginColor.knochen, red: 0xEC, green: 0xE6, blue: 0xD9)
    }
    private func assertRGB(_ color: Color, red: UInt8, green: UInt8, blue: UInt8) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, CGFloat(red) / 255, accuracy: 0.002)
        XCTAssertEqual(g, CGFloat(green) / 255, accuracy: 0.002)
        XCTAssertEqual(b, CGFloat(blue) / 255, accuracy: 0.002)
    }
    func testAkteurFarbe() {
        XCTAssertEqual(HuginColor.actor(.local), HuginColor.glut)
        XCTAssertEqual(HuginColor.actor(.claude), HuginColor.frost)
        XCTAssertEqual(HuginColor.actor(nil), HuginColor.glut)   // neutrale Knoten = Glut-Ton
    }
    func testFontsGebundelt() {
        // PostScript-/Full-Namen – der Familienname liefert bei UIFont typisch nil
        XCTAssertNotNil(UIFont(name: "Geist-Regular", size: 14))
        XCTAssertNotNil(UIFont(name: "Geist-Medium", size: 14))
        XCTAssertNotNil(UIFont(name: "Geist-SemiBold", size: 14))
        XCTAssertNotNil(UIFont(name: "GeistMono-Regular", size: 12))
    }
}
