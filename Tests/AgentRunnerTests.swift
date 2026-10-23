import XCTest
@testable import Hugin

final class AgentRunnerTests: XCTestCase {
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

    private func makeRunner(script: [ProviderResponse],
                            actor: Actor = .local,
                            findings: FindingBuffer = FindingBuffer(),
                            confirm: @Sendable @escaping (ConfirmRequest) async -> Bool = { _ in true })
        -> (AgentRunner, FakeProvider, CardBuffer) {
        let cards = CardBuffer()
        let fake = FakeProvider(script: script, actor: actor)
        let runner = AgentRunner(provider: fake, fileTools: tools, backupDir: backup,
                                 onCard: { cards.add($0) }, onFinding: { findings.add($0) }, confirm: confirm)
        return (runner, fake, cards)
    }

    func testLoopKomplett() async throws {
        let (runner, _, cards) = makeRunner(script: [
            .init(text: "", toolCalls: [
                .init(id: "1", name: "list_files", arguments: .object(["folder": .string("Doku")]))]),
            .init(text: "Fertig: 1 Datei", toolCalls: [])
        ])
        try "x".write(to: tmp.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        let result = try await runner.run(userText: "Liste Dateien", prior: [])
        guard case .completed(let text, _) = result else { return XCTFail("completed erwartet") }
        XCTAssertEqual(text, "Fertig: 1 Datei")
        let listCard = cards.all.first { $0.kind == .list }
        XCTAssertNotNil(listCard)
        XCTAssertEqual(listCard?.actor, .local)
        XCTAssertNotNil(listCard?.durationMS)   // Dauer gemessen
    }

    func testKartenTragenAkteur() async throws {
        let (runner, _, cards) = makeRunner(script: [
            .init(text: "", toolCalls: [
                .init(id: "1", name: "list_files", arguments: .object(["folder": .string("Doku")]))]),
            .init(text: "ok", toolCalls: [])
        ], actor: .claude)
        _ = try await runner.run(userText: "x", prior: [])
        XCTAssertEqual(cards.all.first?.actor, .claude)
    }

    func testNoteFinding() async throws {
        let findings = FindingBuffer()
        let (runner, _, cards) = makeRunner(script: [
            .init(text: "", toolCalls: [
                .init(id: "1", name: "note_finding", arguments: .object([
                    "name": .string("Strom"), "value": .string("64,20 EUR")]))]),
            .init(text: "fertig", toolCalls: [])
        ], findings: findings)
        _ = try await runner.run(userText: "x", prior: [])
        XCTAssertEqual(findings.all.count, 1)
        XCTAssertEqual(findings.all.first?.name, "Strom")
        XCTAssertEqual(findings.all.first?.actor, .local)
        XCTAssertFalse(cards.all.contains { $0.kind == .error })  // Finding ist kein Fehler
    }

    func testAbbruchWirftCancellation() async throws {
        let (runner, _, _) = makeRunner(script: [
            .init(text: "", toolCalls: [
                .init(id: "1", name: "list_files", arguments: .object(["folder": .string("Doku")]))])])
        let task = Task { try await runner.run(userText: "x", prior: []) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Cancellation erwartet")
        } catch { /* CancellationError – „Anhalten“ funktioniert */ }
    }

    func testWerkzeuglimit() async throws {
        let loopCall = ProviderResponse(text: "", toolCalls: [
            .init(id: "x", name: "list_files", arguments: .object(["folder": .string("Doku")]))])
        let (runner, fake, _) = makeRunner(script: [loopCall])
        let result = try await runner.run(userText: "Endlos", prior: [])
        guard case .limitReached = result else { return XCTFail("limitReached erwartet") }
        XCTAssertEqual(fake.received.count, AgentRunner.maxSteps)
    }

    func testBestaetigungAbgelehnt() async throws {
        try "a".write(to: tmp.appendingPathComponent("n.txt"), atomically: true, encoding: .utf8)
        let seen = ConfirmCatcher()
        let (runner, _, cards) = makeRunner(script: [
            .init(text: "", toolCalls: [
                .init(id: "1", name: "write_file", arguments: .object([
                    "path": .string("Doku/n.txt"), "content": .string("neu"), "overwrite": .bool(false)]))]),
            .init(text: "Ok, nicht geschrieben.", toolCalls: [])
        ], confirm: { req in await seen.record(req); return false })
        let result = try await runner.run(userText: "Überschreibe n.txt", prior: [])
        guard case .completed(let text, _) = result else { return XCTFail() }
        XCTAssertEqual(text, "Ok, nicht geschrieben.")
        XCTAssertEqual(try tools.read("Doku/n.txt"), "a")
        let req = await seen.last
        XCTAssertEqual(req?.path, "Doku/n.txt")
        XCTAssertEqual(req?.oldContent, "a")        // Diff-Daten fürs Halten-Dialog
        XCTAssertEqual(req?.newContent, "neu")
        XCTAssertTrue(cards.all.contains { $0.kind == .hint })  // Ablehnung als Hinweis
    }

    func testOverwriteTrueTrotzdemGate() async throws {
        try "a".write(to: tmp.appendingPathComponent("n.txt"), atomically: true, encoding: .utf8)
        let (runner, _, _) = makeRunner(script: [
            .init(text: "", toolCalls: [.init(id: "1", name: "write_file",
                arguments: .object(["path": .string("Doku/n.txt"), "content": .string("x"), "overwrite": .bool(true)]))]),
            .init(text: "ok", toolCalls: [])
        ], confirm: { _ in false })
        _ = try await runner.run(userText: "x", prior: [])
        // Gate muss auch bei overwrite:true greifen – Datei unverändert
        XCTAssertEqual(try tools.read("Doku/n.txt"), "a")
    }

    func testFehlerWirdBeobachtung() async throws {
        let (runner, fake, _) = makeRunner(script: [
            .init(text: "", toolCalls: [
                .init(id: "1", name: "read_file", arguments: .object(["path": .string("Doku/gibtsnicht.txt")]))]),
            .init(text: "Datei existiert nicht – ich passe an.", toolCalls: [])
        ])
        _ = try await runner.run(userText: "Lese", prior: [])
        // Beobachtung muss als toolResult zurückgegangen sein
        XCTAssertEqual(fake.received.last?.messages.last, .toolResult(id: "1", content: "Fehler: notFound"))
    }
}

actor ConfirmCatcher {
    private(set) var last: ConfirmRequest?
    func record(_ req: ConfirmRequest) { last = req }
}
