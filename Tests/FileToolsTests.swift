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
}
