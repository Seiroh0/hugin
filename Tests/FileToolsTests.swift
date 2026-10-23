import UIKit
import XCTest
@testable import Hugin

final class FileToolsTests: XCTestCase {
    var tmp: URL!
    var tools: FileTools!
    var backup: URL!

    override func setUp() {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        backup = tmp.appendingPathComponent(".backups")
        tools = FileTools(roots: [Grant(id: UUID(), name: "Doku", url: tmp)])
    }
    override func tearDown() { try? FileManager.default.removeItem(at: tmp) }

    func testResolveBlocktFlucht() {
        XCTAssertNil(tools.resolve("Doku/../.."))            // über Wurzel
        XCTAssertNil(tools.resolve("/etc/passwd"))           // absolut
        XCTAssertNil(tools.resolve("Fremd/datei.txt"))       // andere Freigabe
        XCTAssertNotNil(tools.resolve("Doku/a.txt"))
        XCTAssertNotNil(tools.resolve("Doku/./sub/../a.txt"))
    }

    func testSymlinkFluchtBlockiert() throws {
        try FileManager.default.createSymbolicLink(at: tmp.appendingPathComponent("link"),
                                                   withDestinationURL: tmp.deletingLastPathComponent())
        XCTAssertNil(tools.resolve("Doku/link/irgendwas.txt"))
    }

    func testPercentEncodingBleibtInDerSandbox() {
        // „%2e%2e" darf niemals zu einem Pfad außerhalb der Freigabe führen
        if let url = tools.resolve("Doku/%2e%2e/geheim.txt") {
            let real = url.resolvingSymlinksInPath().path
            let root = tmp.resolvingSymlinksInPath().path
            XCTAssertTrue(real == root || real.hasPrefix(root + "/"))
        } // nil wäre auch in Ordnung – Hauptsache nie außerhalb
    }

    func testList() throws {
        try "hello".write(to: tmp.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("sub"), withIntermediateDirectories: true)
        let entries = try tools.list(folder: "Doku")
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.contains { $0.name == "sub" && $0.isFolder && $0.relPath == "Doku/sub" })
        XCTAssertTrue(entries.contains { $0.name == "a.txt" && $0.byteSize == 5 })
        XCTAssertThrowsError(try tools.list(folder: "Doku/gibtsnicht")) { XCTAssertEqual($0 as? FileError, .notFound) }
    }

    func testReadText() throws {
        try "hello".write(to: tmp.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        XCTAssertEqual(try tools.read("Doku/a.txt"), "hello")
    }

    func testReadGrosseDateiWirdAbgeschnitten() throws {
        let big = String(repeating: "x", count: 300_000)
        try big.write(to: tmp.appendingPathComponent("big.txt"), atomically: true, encoding: .utf8)
        let out = try tools.read("Doku/big.txt")
        XCTAssertLessThanOrEqual(out.count, 200_200) // Inhalt + Hinweistext
        XCTAssertTrue(out.contains("abgeschnitten"))
    }

    func testReadPDF() throws {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 200)).pdfData { ctx in
            ctx.beginPage()
            "Rechnung 123".draw(at: .zero, withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
        }
        try data.write(to: tmp.appendingPathComponent("r.pdf"))
        XCTAssertTrue(try tools.read("Doku/r.pdf").contains("Rechnung 123"))
    }

    func testReadNichtUnterstuetzt() throws {
        try Data([0xFF]).write(to: tmp.appendingPathComponent("b.bin"))
        XCTAssertThrowsError(try tools.read("Doku/b.bin")) { XCTAssertEqual($0 as? FileError, .unsupportedFormat) }
    }

    func testReadOrdnerWirftIsFolder() throws {
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("sub"), withIntermediateDirectories: true)
        XCTAssertThrowsError(try tools.read("Doku/sub")) { XCTAssertEqual($0 as? FileError, .isFolder) }
    }

    func testPDFOhneTextlayer() throws {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 100, height: 100)).pdfData { ctx in
            ctx.beginPage()
            ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 50))   // nur Grafik, kein Text
        }
        try data.write(to: tmp.appendingPathComponent("leer.pdf"))
        XCTAssertThrowsError(try tools.read("Doku/leer.pdf")) { XCTAssertEqual($0 as? FileError, .unsupportedFormat) }
    }

    func testUmlauteUndEmoji() throws {
        let name = "Rechnung Ä-ö-ü 🧾.md"
        try "Inhalt".write(to: tmp.appendingPathComponent(name), atomically: true, encoding: .utf8)
        XCTAssertEqual(try tools.read("Doku/\(name)"), "Inhalt")
        // Rename mit Umlauten folgt in Task 7 – hier nur read
    }

    func testSearch() throws {
        try "Rechnung 4711".write(to: tmp.appendingPathComponent("r1.md"), atomically: true, encoding: .utf8)
        try "x".write(to: tmp.appendingPathComponent("anders.txt"), atomically: true, encoding: .utf8)
        let byName = try tools.search(nameContains: "r1", contentContains: nil)
        XCTAssertEqual(byName.map(\.name), ["r1.md"])
        let byContent = try tools.search(nameContains: "", contentContains: "4711")
        XCTAssertEqual(byContent.map(\.name), ["r1.md"])
    }

    func testListDeterministischUndOrdnerOhneGroesse() throws {
        try "b".write(to: tmp.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        try "a".write(to: tmp.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("sub"), withIntermediateDirectories: true)
        let entries = try tools.list(folder: "Doku")
        XCTAssertEqual(entries.map(\.name), ["a.txt", "b.txt", "sub"])
        XCTAssertEqual(entries.first { $0.isFolder }?.byteSize, nil)   // Ordner ohne Größe (Ruling R8)
    }

    func testWriteNeu() throws {
        XCTAssertNil(try tools.write("Doku/neu.md", content: "# x", overwrite: false, backupDir: backup))
        XCTAssertEqual(try tools.read("Doku/neu.md"), "# x")
    }
    func testWriteExistiertOhneOverwrite() throws {
        try tools.write("Doku/n.md", content: "a", overwrite: false, backupDir: backup)
        XCTAssertThrowsError(try tools.write("Doku/n.md", content: "b", overwrite: false, backupDir: backup)) {
            XCTAssertEqual($0 as? FileError, .existsNeedsConfirmation)
        }
    }
    func testOverwriteMitBackup() throws {
        try tools.write("Doku/n.md", content: "a", overwrite: false, backupDir: backup)
        let card = try tools.write("Doku/n.md", content: "b", overwrite: true, backupDir: backup)
        XCTAssertEqual(card?.kind, .backup)
        XCTAssertEqual(try tools.read("Doku/n.md"), "b")
        let backupPath = backup.appendingPathComponent(card!.detail)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupPath.path))
        XCTAssertEqual(try String(contentsOf: backupPath, encoding: .utf8), "a")
    }
    func testRenameUndMove() throws {
        try "x".write(to: tmp.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("sub"), withIntermediateDirectories: true)
        XCTAssertEqual(try tools.rename("Doku/a.txt", to: "b.txt"), "Doku/b.txt")
        XCTAssertEqual(try tools.move("Doku/b.txt", toFolder: "Doku/sub"), "Doku/sub/b.txt")
        XCTAssertThrowsError(try tools.rename("Doku/sub/b.txt", to: "../c.txt")) { XCTAssertEqual($0 as? FileError, .outsideSandbox) }
    }
    func testRenameBlocktDotfiles() throws {
        try "x".write(to: tmp.appendingPathComponent("sichtbar.txt"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try tools.rename("Doku/sichtbar.txt", to: ".versteckt.txt")) { XCTAssertEqual($0 as? FileError, .outsideSandbox) }
    }
    func testRenameMitUmlauten() throws {
        let name = "Rechnung Ä-ö-ü 🧾.md"
        try "Inhalt".write(to: tmp.appendingPathComponent(name), atomically: true, encoding: .utf8)
        XCTAssertEqual(try tools.rename("Doku/\(name)", to: "Neu-Ä.md"), "Doku/Neu-Ä.md")
    }
}
