import XCTest
@testable import Hugin

@MainActor
final class ChatViewModelTests: XCTestCase {
    func makeVM(makeProvider: @escaping @MainActor (ChatViewModel.Mode, CardBuffer, FindingBuffer) throws -> ModelProvider) throws -> ChatViewModel {
        ChatViewModel(store: try HuginStore(inMemory: true), makeProvider: makeProvider)
    }

    func testRunHaengtAntwortAn() async throws {
        let fake = FakeProvider(script: [.init(text: "Erledigt", toolCalls: [])])
        let vm = try makeVM { _, _, _ in fake }
        vm.run("test")
        await vm.waitForRunEnd()
        XCTAssertEqual(vm.messages.first?.role, .user)
        XCTAssertEqual(vm.messages.last?.text, "Erledigt")
        XCTAssertEqual(vm.status, .idle)
        XCTAssertNotNil(vm.currentOrderID)          // neuer Auftrag angelegt
        XCTAssertEqual(vm.munin.count, 1)          // Munin-Eintrag vorhanden
        XCTAssertEqual(vm.munin.first?.title, "test")
    }

    func testAutoEskaliertBeiUnavailable() async throws {
        let claude = FakeProvider(script: [.init(text: "via Claude", toolCalls: [])], actor: .claude)
        let vm = try makeVM { mode, _, _ in
            if mode == .onDevice { throw ModelError.unavailable }
            return claude
        }
        vm.mode = .auto
        vm.run("mach was")
        await vm.waitForRunEnd()
        XCTAssertEqual(vm.messages.last?.text, "via Claude")
        let assistant = vm.messages.last!
        XCTAssertTrue(assistant.cards.contains { $0.kind == .handover })   // ÜBERGABE-Knoten
    }

    struct UnavailableProvider: ModelProvider, Sendable {
        let name = "Unavailable"
        let actor: Actor = .local
        func respond(system: String, messages: [ProviderMessage], tools: [ToolSpec]) async throws -> ProviderResponse {
            throw ModelError.unavailable   // wirft erst ZUR LAUFZEIT (nicht bei der Factory)
        }
    }

    func testAutoEskaliertBeiLaufzeitFehler() async throws {
        let claude = FakeProvider(script: [.init(text: "via Claude gerettet", toolCalls: [])], actor: .claude)
        let vm = try makeVM { mode, _, _ in
            if mode == .onDevice { return UnavailableProvider() as any ModelProvider }
            return claude
        }
        vm.mode = .auto
        vm.run("mach was")
        await vm.waitForRunEnd()
        XCTAssertEqual(vm.messages.last?.text, "via Claude gerettet")
        XCTAssertTrue(vm.messages.last?.cards.contains { $0.kind == .handover } == true)  // Laufzeit-Übergabe
    }

    func testVerlaufWirdGespeichert() async throws {
        let fake = FakeProvider(script: [.init(text: "ok", toolCalls: [])])
        let store = try HuginStore(inMemory: true)
        let vm = ChatViewModel(store: store, makeProvider: { _, _, _ in fake })
        vm.run("hallo")
        await vm.waitForRunEnd()
        let orderID = try XCTUnwrap(vm.currentOrderID)
        let loaded = store.load(orderID: orderID)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.last?.text, "ok")
    }

    func testQueueStartetNachLauf() async throws {
        let fake = FakeProvider(script: [.init(text: "ok", toolCalls: [])])
        let vm = try makeVM { _, _, _ in fake }
        vm.run("eins")
        vm.queueDraft("zwei")   // während des ersten Laufs vorgemerkt
        await vm.waitForRunEnd()
        await vm.waitForRunEnd()   // zweiter (Queue-)Lauf
        XCTAssertEqual(vm.munin.count, 2)
        XCTAssertEqual(Set(vm.munin.map(\.title)), ["eins", "zwei"])
        XCTAssertNil(vm.queuedDraft)
    }

    func testBestaetigungsBruecke() async throws {
        // Freigabe + existierende Datei nötig, damit write_file den Dialog auslöst
        let sec = SecurityStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        try "a".write(to: tmp.appendingPathComponent("exists.txt"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let grant = try sec.addGrant(url: tmp)
        let fake = FakeProvider(script: [
            .init(text: "", toolCalls: [.init(id: "1", name: "write_file",
                arguments: .object(["path": .string("\(grant.name)/exists.txt"), "content": .string("x")]))]),
            .init(text: "fertig", toolCalls: [])
        ])
        let vm = ChatViewModel(security: sec, store: try HuginStore(inMemory: true), makeProvider: { _, _, _ in fake })
        vm.run("schreibe")
        var tries = 0
        while vm.pendingConfirmation == nil && tries < 500 {   // begrenzter Wait statt Endlos-Schleife
            try? await Task.sleep(for: .milliseconds(10)); tries += 1
        }
        XCTAssertNotNil(vm.pendingConfirmation, "Bestätigungsdialog kam nicht (innerhalb von 5 s)")
        if let conf = vm.pendingConfirmation {
            XCTAssertTrue(conf.request.path.contains("exists.txt"))
            XCTAssertEqual(conf.request.oldContent, "a")   // Diff-Daten für den Halten-Dialog
            XCTAssertEqual(conf.request.newContent, "x")
            vm.resolveConfirmation(false)
        }
        await vm.waitForRunEnd()
        XCTAssertEqual(vm.messages.last?.text, "fertig")
        XCTAssertEqual(try String(contentsOf: tmp.appendingPathComponent("exists.txt"), encoding: .utf8), "a")
    }

    func testMuninUeberlebtNeustart() async throws {
        let fake = FakeProvider(script: [.init(text: "ok", toolCalls: [])])
        let store = try HuginStore(inMemory: true)
        let vm1 = ChatViewModel(store: store, makeProvider: { _, _, _ in fake })
        vm1.run("hallo")
        await vm1.waitForRunEnd()
        let vm2 = ChatViewModel(store: store, makeProvider: { _, _, _ in fake })  // gleicher Store
        vm2.load()
        XCTAssertEqual(vm2.munin.count, 1)                       // Historie da
        let orderID = try XCTUnwrap(vm2.munin.first?.id)
        vm2.open(orderID: orderID)
        XCTAssertEqual(vm2.messages.count, 2)                   // Auftrag einsehbar
    }

    func testDoppelterRunBlockiert() async throws {
        let fake = FakeProvider(script: [.init(text: "ok", toolCalls: [])])
        let vm = try makeVM { _, _, _ in fake }
        vm.run("eins")
        vm.run("zwei")   // während des ersten Laufs verworfen
        await vm.waitForRunEnd()
        XCTAssertEqual(vm.messages.count, 2) // 1× Nutzer + 1× Antwort
        XCTAssertEqual(vm.munin.count, 1)    // nur ein Auftrag
    }

    struct HangingProvider: ModelProvider, Sendable {
        let name = "Hanging"
        let actor: Actor = .local
        func respond(system: String, messages: [ProviderMessage], tools: [ToolSpec]) async throws -> ProviderResponse {
            while true {
                try Task.checkCancellation()   // bricht mit CancellationError ab, sobald stop() feuert
                try await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    func testAnhalten() async throws {
        let vm = try makeVM { _, _, _ in HangingProvider() }
        vm.run("dauert lange")
        try await Task.sleep(for: .milliseconds(200))   // Lauf ist aktiv
        XCTAssertEqual(vm.status, .thinking)
        vm.stop()
        await vm.waitForRunEnd()
        XCTAssertEqual(vm.messages.last?.text, "Angehalten.")
        XCTAssertEqual(vm.status, .idle)
        XCTAssertNil(vm.running)                       // Running-Pill weg
        vm.run("nochmal")                              // Folgeauftrag möglich …
        vm.stop()
        await vm.waitForRunEnd()
        XCTAssertEqual(vm.munin.count, 2)
    }
}
