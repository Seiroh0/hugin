# PadPilot MVP – Umsetzungsplan

> **Für ausführende Agenten:** BENÖTIGTES SUB-SKILL: superpowers:subagent-driven-development (empfohlen) oder superpowers:executing-plans, um diesen Plan Aufgabe für Aufgabe umzusetzen. Schritte nutzen Checkbox-Syntax (`- [ ]`).

**Ziel:** Eine native iPad-App („PadPilot"), in der ein KI-Agent per Chat Dateien in freigegebenen Ordnern findet, liest, zusammenfasst, bearbeitet, umbenennt und verschiebt.

**Architektur:** SwiftUI-App mit Agent-Loop (Plan → Werkzeugaufruf → Beobachtung → Antwort), Modell-Abstraktion (`ModelProvider`) mit zwei Implementierungen (Apple Foundation Models on-device, Claude per HTTPS) und reinen Datei-Werkzeugen mit Sandbox-Containment-Check. Build/Tests ausschließlich über GitHub Actions (macOS-Runner), da lokal nur Windows vorhanden ist.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, PDFKit, FoundationModels, URLSession, XCTest, XcodeGen (Projektgenerierung in CI).

**Spec:** `docs/superpowers/specs/2026-10-23-ipad-ki-agent-design.md` – dieser Plan argumentiert aus der Spec; Ausführende lesen beide.

## Globale Randbedingungen

- Swift 6 / SwiftUI; Deployment-Target iPadOS 26.0 (läuft auf dem iPad Air 5 mit iPadOS 27.0.1)
- **Keine externen Dependencies** – ausschließlich Apple-Frameworks
- **Kein Löschen-Werkzeug.** Überschreiben nur mit Nutzer-Bestätigung + automatischem Backup
- **Max. 15 Werkzeugaufrufe pro Auftrag** (AgentRunner)
- Dateioperationen **nur innerhalb** security-scoped Freigaben (Containment-Check `resolve()`)
- Claude-API-Key nur im Keychain, niemals in Code/Repo/Logs; UI- und Kommentarsprache Deutsch
- Tests: XCTest, laufen in GitHub Actions (macOS-Runner, iOS-Simulator). **TDD-Anpassung:** lokal kein Swift verfügbar → Test wird vor Implementation geschrieben, Rot-Phase wird im selben CI-Run geprüft (Test schlägt bei falscher Implementierung fehl, Tests sind verhaltensspezifisch). Bei jedem Task: Commit + Push, CI muss grün sein, bevor der nächste Task beginnt.
- Commits: Conventional Commits (`feat:`, `test:`, `build:`, `docs:`)
- CI-Stellschrauben (bewusst): Runner-Image `macos-26`, Simulator-Name im Workflow – anpassen, falls CI sie nicht findet (`xcrun simctl list devices available` steht im CI-Log)

## Nutzerschritte (nicht automatisierbar, in Task 1 und 14 verankert)

1. Gratis-Apple-ID (fertig vorhanden), GitHub-Konto anlegen
2. Privates/public GitHub-Repo anlegen (Empfehlung: public → macOS-CI gratis, Repo enthält keine Secrets), dann: `git remote add origin <URL> && git push -u origin master`
3. Nach CI-Lauf: Artifact `PadPilot-unsigned.ipa` herunterladen, per USB mit Sideloadly (Windows) + Apple-ID signieren/installieren (oder über Tailscale an den Rechner übertragen)
4. Auf dem iPad: Einstellungen → Allgemein → VPN & Geräteverwaltung → Entwicklerprofil vertrauen
5. Gratis-Account: App verfällt nach 7 Tagen → Schritt 3 wiederholen; Daten bleiben erhalten

---

### Task 1: Repo-Grundgerüst & CI-Skelett

**Files:**
- Create: `.gitignore`, `project.yml`, `Sources/App/PadPilotApp.swift`, `Sources/UI/ChatView.swift` (Platzhalter, wird in Task 14 ersetzt), `Tests/SmokeTests.swift`, `.github/workflows/ci.yml`, `README.md`

**Interfaces:**
- Produces: laufende CI (grün), XcodeGen-Projekt-Definition für alle späteren Tasks; App-Target „PadPilot", Test-Target „PadPilotTests"

- [ ] **Schritt 1: Grunddateien schreiben**

`.gitignore`:
```
DerivedData/
build/
*.xcodeproj
xcuserdata/
.DS_Store
```
(`*.xcodeproj` wird ignoriert, weil XcodeGen es in CI generiert.)

`project.yml`:
```yaml
name: PadPilot
options:
  bundleIdPrefix: com.padpilot
  deploymentTarget:
    iOS: "26.0"
settings:
  base:
    CODE_SIGNING_ALLOWED: "NO"
    CODE_SIGN_IDENTITY: ""
    GENERATE_INFOPLIST_FILE: "YES"
targets:
  PadPilot:
    type: application
    platform: iOS
    sources:
      - Sources/App
      - Sources/Core
      - Sources/Store
      - Sources/UI
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.padpilot.app
        INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationPortrait
        TARGETED_DEVICE_FAMILY: "2"
  PadPilotTests:
    type: bundle.unit-test
    platform: iOS
    sources: [Tests]
    dependencies:
      - target: PadPilot
schemes:
  PadPilot:
    build:
      targets: { PadPilot: all }
    test:
      targets: [PadPilotTests]
```

`Sources/App/PadPilotApp.swift`:
```swift
import SwiftUI

@main
struct PadPilotApp: App {
    var body: some Scene {
        WindowGroup { ChatView() }
    }
}
```

`Sources/UI/ChatView.swift` (Platzhalter):
```swift
import SwiftUI

struct ChatView: View {
    var body: some View { Text("PadPilot") }
}
```

`Tests/SmokeTests.swift`:
```swift
import XCTest
@testable import PadPilot

final class SmokeTests: XCTestCase {
    func testSmoke() { XCTAssertTrue(true) }
}
```

- [ ] **Schritt 2: CI-Workflow schreiben**

`.github/workflows/ci.yml`:
```yaml
name: CI
on: [push]
jobs:
  build-test-ipa:
    runs-on: macos-26
    steps:
      - uses: actions/checkout@v4
      - name: XcodeGen installieren
        run: brew install xcodegen
      - name: Projekt generieren
        run: xcodegen generate
      - name: Verfügbare Simulatoren (Debug-Hilfe)
        run: xcrun simctl list devices available
      - name: Tests
        run: xcodebuild -project PadPilot.xcodeproj -scheme PadPilot -destination 'platform=iOS Simulator,name=iPad (A16) Simulator' test
      - name: Unsigned IPA bauen
        run: |
          xcodebuild -project PadPilot.xcodeproj -scheme PadPilot -configuration Release -sdk iphoneos archive -archivePath build/PadPilot.xcarchive
          mkdir -p build/Payload
          cp -R "build/PadPilot.xcarchive/Products/Applications/PadPilot.app" build/Payload/
          cd build && zip -r PadPilot-unsigned.ipa Payload
      - uses: actions/upload-artifact@v4
        with:
          name: PadPilot-unsigned
          path: build/PadPilot-unsigned.ipa
```

`README.md`:
```markdown
# PadPilot
KI-Datei-Agent fürs iPad (Details: docs/superpowers/specs/…-design.md)

## Installation (ohne Mac)
1. **GitHub-Repo anlegen** (public empfohlen – macOS-CI gratis, keine Secrets im Repo) und pushen:
   `git remote add origin <REPO-URL>` → `git push -u origin master`
2. **CI abwarten**: Actions-Tab → Run „CI" → grün → Artifact `PadPilot-unsigned.ipa` herunterladen (ggf. über Tailscale auf den PC holen)
3. **Sideloadly** (sideloadly.io, Windows) installieren; iTunes-Treiber mitinstallieren lassen
4. iPad per **USB** an den PC, Sideloadly starten: IPA wählen → Apple-ID eintragen → Install
5. iPad: **Einstellungen → Allgemein → VPN & Geräteverwaltung** → Apple-ID-Profil → **Vertrauen**
6. App starten → Einstellungen → Claude-API-Key eintragen, Ordner freigeben

**Gratis-Apple-ID:** App läuft 7 Tage, dann Schritt 4 wiederholen (Daten bleiben).
**Nur zur eigenen Nutzung** – kein App-Store-Vertrieb.
```

- [ ] **Schritt 3: Nutzer-Handschritt** – GitHub-Repo anlegen + `git remote add origin <URL> && git push -u origin master`
- [ ] **Schritt 4: CI-Run prüfen** – Erwartung: grün; falls Simulator-Name/Runner-Image nicht gefunden: aus CI-Log ablesen und in `ci.yml` korrigieren
- [ ] **Schritt 5: Commit**
```bash
git add -A
git commit -m "build: Projektgerüst, XcodeGen, CI mit Tests und unsigned IPA"
git push
```

---

### Task 2: JSONValue

**Files:**
- Create: `Sources/Core/JSONValue.swift`
- Test: `Tests/JSONValueTests.swift`

**Interfaces:**
- Produces: `enum JSONValue: Codable, Sendable, Equatable` mit `.null/.bool/.number/.string/.array/.object`, `static func from(data:)`, `func data() throws -> Data`, `subscript(key: String) -> JSONValue?`, `stringValue/doubleValue/boolValue`

- [ ] **Schritt 1: Tests schreiben**
```swift
import XCTest
@testable import PadPilot

final class JSONValueTests: XCTestCase {
    func testRoundtrip() throws {
        let src: JSONValue = .object(["a": .number(1), "b": .string("x"),
            "c": .array([.bool(true), .null])])
        let back = try JSONValue.from(data: try src.data())
        XCTAssertEqual(back, src)
    }
    func testAccessors() {
        let v: JSONValue = .object(["n": .number(2.5), "s": .string("hi"), "b": .bool(true)])
        XCTAssertEqual(v["n"]?.doubleValue, 2.5)
        XCTAssertEqual(v["s"]?.stringValue, "hi")
        XCTAssertEqual(v["b"]?.boolValue, true)
        XCTAssertEqual(v["s"]?.boolValue, nil)
    }
}
```
- [ ] **Schritt 2: Implementierung**
```swift
import Foundation

enum JSONValue: Codable, Sendable, Equatable {
    case null, bool(Bool), number(Double), string(String)
    case array([JSONValue]), object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else { self = .null }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
    var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    var doubleValue: Double? { if case .number(let n) = self { return n }; return nil }
    var boolValue: Bool? { if case .bool(let b) = self { return b }; return nil }
    subscript(key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }; return nil
    }
    static func from(data: Data) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: data) }
    func data() throws -> Data { try JSONEncoder().encode(self) }
}
```
- [ ] **Schritt 3: Commit + Push + CI grün**
```bash
git add Sources/Core/JSONValue.swift Tests/JSONValueTests.swift
git commit -m "feat: JSONValue als werkzeugspezifischer JSON-Typ"
git push
```

---

### Task 3: Provider-Verträge + FakeProvider

**Files:**
- Create: `Sources/Core/ModelProvider.swift`
- Test: `Tests/FakeProviderTests.swift`

**Interfaces:**
- Produces: `struct ToolSpec { name, description, inputSchema: JSONValue }`, `struct ToolCall { id, name, arguments: JSONValue }`, `struct ProviderResponse { text, toolCalls }`, `enum ProviderMessage { user(String) / assistant(text, toolCalls) / toolResult(id, content) }`, `protocol ModelProvider: Sendable { var name: String; func respond(system:, messages:, tools:) async throws -> ProviderResponse }`, `enum ModelError { unavailable, unauthorized, network(String) }`, `final class FakeProvider` (wiederholt letzte Script-Antwort)

- [ ] **Schritt 1: Tests schreiben**
```swift
import XCTest
@testable import PadPilot

final class FakeProviderTests: XCTestCase {
    func testScriptUndProtokoll() async throws {
        let fake = FakeProvider(script: [.init(text: "ok", toolCalls: [])])
        let r = try await fake.respond(system: "sys", messages: [.user("hi")], tools: [])
        XCTAssertEqual(r.text, "ok")
        XCTAssertEqual(fake.received.count, 1)
        XCTAssertEqual(fake.received[0].system, "sys")
    }
    func testWiederholtLetzteAntwort() async throws {
        let fake = FakeProvider(script: [.init(text: "", toolCalls: [.init(id: "1", name: "x", arguments: .object([:]))])])
        _ = try await fake.respond(system: "s", messages: [], tools: [])
        _ = try await fake.respond(system: "s", messages: [], tools: [])
        XCTAssertEqual(fake.received.count, 2)
    }
}
```
- [ ] **Schritt 2: Implementierung**
```swift
import Foundation

struct ToolSpec: Codable, Sendable, Equatable {
    let name: String
    let description: String
    let inputSchema: JSONValue
}

struct ToolCall: Sendable, Equatable {
    let id: String
    let name: String
    let arguments: JSONValue
}

struct ProviderResponse: Sendable, Equatable {
    let text: String
    let toolCalls: [ToolCall]
}

enum ProviderMessage: Sendable, Equatable {
    case user(String)
    case assistant(text: String, toolCalls: [ToolCall])
    case toolResult(id: String, content: String)
}

enum ModelError: Error, Equatable {
    case unavailable      // on-device-Modell fehlt (z. B. CI-Simulator)
    case unauthorized     // Claude-Key ungültig
    case network(String)
}

protocol ModelProvider: Sendable {
    var name: String { get }
    func respond(system: String, messages: [ProviderMessage], tools: [ToolSpec]) async throws -> ProviderResponse
}

final class FakeProvider: ModelProvider, @unchecked Sendable {
    let name = "Fake"
    private let script: [ProviderResponse]
    private(set) var received: [(system: String, messages: [ProviderMessage], tools: [ToolSpec])] = []
    private var calls = 0
    init(script: [ProviderResponse]) { self.script = script }
    func respond(system: String, messages: [ProviderMessage], tools: [ToolSpec]) async throws -> ProviderResponse {
        received.append((system, messages, tools))
        let r = script[min(calls, script.count - 1)]
        calls += 1
        return r
    }
}
```
- [ ] **Schritt 3: Commit + Push + CI grün** – `git commit -m "feat: ModelProvider-Verträge und FakeProvider"`

---

### Task 4: Chat-Typen (ChatMessage, ActionCard)

**Files:**
- Create: `Sources/Core/ChatMessage.swift`
- Test: `Tests/ChatMessageTests.swift`

**Interfaces:**
- Produces: `enum Role { user, assistant, system }`, `enum CardKind { list, search, read, write, rename, move, backup, error, hint }`, `struct ActionCard: Codable, Sendable, Identifiable, Equatable { id, kind, title, detail, createdAt }`, `struct ChatMessage: Codable, Sendable, Identifiable, Equatable { id, role, text, cards, createdAt }` (Init mit Default-UUID/Date)

- [ ] **Schritt 1: Test schreiben**
```swift
import XCTest
@testable import PadPilot

final class ChatMessageTests: XCTestCase {
    func testCodableRoundtrip() throws {
        let m = ChatMessage(role: .assistant, text: "Fertig",
            cards: [ActionCard(id: UUID(), kind: .read, title: "gelesen", detail: "Doku/a.md", createdAt: Date())])
        let data = try JSONEncoder().encode(m)
        let back = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(back.text, "Fertig")
        XCTAssertEqual(back.cards.first?.kind, .read)
        XCTAssertEqual(back.cards.first?.detail, "Doku/a.md")
    }
}
```
- [ ] **Schritt 2: Implementierung**
```swift
import Foundation

enum Role: String, Codable, Sendable { case user, assistant, system }

enum CardKind: String, Codable, Sendable { case list, search, read, write, rename, move, backup, error, hint }

struct ActionCard: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let kind: CardKind
    let title: String
    let detail: String
    let createdAt: Date
}

struct ChatMessage: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let role: Role
    let text: String
    let cards: [ActionCard]
    let createdAt: Date
    init(role: Role, text: String, cards: [ActionCard] = []) {
        self.id = UUID(); self.role = role; self.text = text
        self.cards = cards; self.createdAt = Date()
    }
}
```
- [ ] **Schritt 3: Commit + Push + CI grün** – `git commit -m "feat: Chat- und ActionCard-Typen"`

---

### Task 5: FileTools I – resolve + list (Sandbox-Containment)

**Files:**
- Create: `Sources/Core/Grant.swift`, `Sources/Core/FileTools.swift`, `Tests/FileToolsTests.swift`

**Interfaces:**
- Produces: `struct Grant: Identifiable, Equatable, Sendable { id: UUID, name: String, url: URL }` (SecurityStore in Task 8 produziert `[Grant]`), `struct FileTools: Sendable { init(roots: [Grant]) }`, `func resolve(String) -> URL?` (nil bei Fluchtversuch), `func list(folder: String) throws -> [FileEntry]`, `struct FileEntry { relPath, name, isFolder, byteSize: Int? }`, `enum FileError: Error, Equatable { outsideSandbox, notFound, notAFolder, isFolder, unsupportedFormat, existsNeedsConfirmation, ioFailure(String) }`

- [ ] **Schritt 1: Tests schreiben**
```swift
import XCTest
@testable import PadPilot

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
```
- [ ] **Schritt 2: Implementierung**
```swift
import Foundation

struct Grant: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let url: URL
}

struct FileEntry: Codable, Sendable, Equatable {
    let relPath: String
    let name: String
    let isFolder: Bool
    let byteSize: Int?
}

enum FileError: Error, Equatable {
    case outsideSandbox, notFound, notAFolder, isFolder
    case unsupportedFormat, existsNeedsConfirmation, ioFailure(String)
}

struct FileTools: Sendable {
    let roots: [Grant]

    /// Löst „FreigabeName/rest/pfad" zu einer URL **innerhalb** dieser Freigabe auf.
    /// Liefert nil bei Fluchtversuch („..", absoluter Pfad, unbekannte Freigabe).
    func resolve(_ relPath: String) -> URL? {
        var comps = relPath.split(separator: "/").map(String.init)
        guard let firstName = comps.first,
              let root = roots.first(where: { $0.name == firstName })
        else { return nil }
        comps.removeFirst()
        var stack: [String] = []
        for c in comps {
            if c == "." { continue }
            if c == ".." { guard !stack.isEmpty else { return nil }; stack.removeLast() }
            else { stack.append(c) }
        }
        return stack.reduce(root.url) { $0.appendingPathComponent($1) }
    }

    func list(folder relPath: String) throws -> [FileEntry] {
        guard let url = resolve(relPath) else { throw FileError.outsideSandbox }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { throw FileError.notFound }
        guard isDir.boolValue else { throw FileError.notAFolder }
        let items = try FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey])
        return items
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .map { entry($0, rootName: rootName(of: relPath)) }
    }

    private func entry(_ url: URL, rootName: String) -> FileEntry {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        let rel = relPath(of: url)
        return FileEntry(relPath: rel, name: url.lastPathComponent,
                         isFolder: values?.isDirectory ?? false, byteSize: values?.fileSize)
    }

    private func rootName(of relPath: String) -> String {
        String(relPath.split(separator: "/").first ?? "")
    }

    func relPath(of url: URL) -> String {
        for root in roots where url.path.hasPrefix(root.url.path) {
            let sub = String(url.path.dropFirst(root.url.path.count + 1))
            return sub.isEmpty ? root.name : "\(root.name)/\(sub)"
        }
        return url.lastPathComponent
    }
}
```
- [ ] **Schritt 3: Commit + Push + CI grün** – `git commit -m "feat: FileTools-Sandbox mit Containment-Check, list"`
- [ ] **Schritt 4: Review-Fokus-Verankerung** – Pfad-Flucht (`../`, absolut, Fremd-Freigabe) ist durch `testResolveBlocktFlucht` dauerhaft getestet.

---

### Task 6: FileTools II – read + search

**Files:**
- Modify: `Sources/Core/FileTools.swift`
- Test: `Tests/FileToolsTests.swift` (erweitern)

**Interfaces:**
- Consumes: Task-5-Typen. Produces: `func read(_ relPath: String) throws -> String` (Textformate + PDF-Text, >200 KB wird abgeschnitten mit Hinweis), `func search(nameContains: String, contentContains: String?) throws -> [FileEntry]`; Konstanten `maxReadBytes = 200_000`, `textExtensions`, `readableExtensions`

- [ ] **Schritt 1: Tests hinzufügen**
```swift
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

    func testSearch() throws {
        try "Rechnung 4711".write(to: tmp.appendingPathComponent("r1.md"), atomically: true, encoding: .utf8)
        try "x".write(to: tmp.appendingPathComponent("anders.txt"), atomically: true, encoding: .utf8)
        let byName = try tools.search(nameContains: "4711", contentContains: nil)
        XCTAssertEqual(byName.map(\.name), ["r1.md"])
        let byContent = try tools.search(nameContains: "", contentContains: "4711")
        XCTAssertEqual(byContent.map(\.name), ["r1.md"])
    }
```
- [ ] **Schritt 2: Implementierung (in FileTools.swift ergänzen)**
```swift
    static let maxReadBytes = 200_000
    static let textExtensions: Set<String> = ["txt","md","csv","json","log","swift","py","html","xml","yml","yaml"]
    static let readableExtensions: Set<String> = ["pdf"]

    func read(_ relPath: String) throws -> String {
        guard let url = resolve(relPath) else { throw FileError.outsideSandbox }
        guard FileManager.default.fileExists(atPath: url.path) else { throw FileError.notFound }
        let ext = url.pathExtension.lowercased()
        let content: String
        if ext == "pdf" {
            guard let doc = PDFDocument(url: url), let text = doc.string else { throw FileError.unsupportedFormat }
            content = text
        } else if Self.textExtensions.contains(ext) {
            let data = FileManager.default.contents(atPath: url.path) ?? Data()
            if data.count > Self.maxReadBytes {
                return String(decoding: data.prefix(Self.maxReadBytes), as: UTF8.self)
                    + "\n[… Datei zu groß, Rest abgeschnitten]"
            }
            content = String(decoding: data, as: UTF8.self)
        } else { throw FileError.unsupportedFormat }
        if content.count > Self.maxReadBytes {
            return String(content.prefix(Self.maxReadBytes)) + "\n[… Datei zu groß, Rest abgeschnitten]"
        }
        return content
    }

    func search(nameContains: String, contentContains: String?) throws -> [FileEntry] {
        var hits: [FileEntry] = []
        for root in roots {
            let enums = FileManager.default.enumerator(at: root.url, includingPropertiesForKeys: [.isDirectoryKey])
            while let raw = enums?.nextObject() as? URL {
                let name = raw.lastPathComponent
                if name.hasPrefix(".") { continue }
                if !nameContains.isEmpty && !name.localizedCaseInsensitiveContains(nameContains) { continue }
                if let contentContains, !contentContains.isEmpty {
                    let rel = relPath(of: raw)
                    guard let text = try? read(rel), text.localizedCaseInsensitiveContains(contentContains) else { continue }
                }
                hits.append(entry(raw, rootName: root.name))
            }
        }
        return hits.sorted { $0.relPath < $1.relPath }
    }
```
Zusätzlich `import PDFKit` am Dateikopf.
- [ ] **Schritt 3: Commit + Push + CI grün** – `git commit -m "feat: read mit PDF/Truncierung und rekursive Suche"`
- [ ] **Schritt 4: Review-Fokus** – Riesendatei-Truncation durch `testReadGrosseDateiWirdAbgeschnitten` getestet.

---

### Task 7: FileTools III – write (mit Backup), rename, move

**Files:**
- Modify: `Sources/Core/FileTools.swift`
- Test: `Tests/FileToolsTests.swift` (erweitern)

**Interfaces:**
- Produces: `@discardableResult func write(_ relPath: String, content: String, overwrite: Bool, backupDir: URL) throws -> ActionCard?` (Backup-Karte zurück, wenn überschrieben wurde; `existsNeedsConfirmation`, wenn Datei existiert und `overwrite == false`), `func rename(_ relPath: String, to newName: String) throws -> String`, `func move(_ relPath: String, toFolder: String) throws -> String` (beide geben neuen relPath zurück)

- [ ] **Schritt 1: Tests hinzufügen**
```swift
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
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupPath))
        XCTAssertEqual(try String(contentsOf: backupPath, encoding: .utf8), "a")
    }
    func testRenameUndMove() throws {
        try "x".write(to: tmp.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("sub"), withIntermediateDirectories: true)
        XCTAssertEqual(try tools.rename("Doku/a.txt", to: "b.txt"), "Doku/b.txt")
        XCTAssertEqual(try tools.move("Doku/b.txt", toFolder: "Doku/sub"), "Doku/sub/b.txt")
        XCTAssertThrowsError(try tools.rename("Doku/sub/b.txt", to: "../c.txt")) { XCTAssertEqual($0 as? FileError, .outsideSandbox) }
    }
```
- [ ] **Schritt 2: Implementierung (ergänzen)**
```swift
    @discardableResult
    func write(_ relPath: String, content: String, overwrite: Bool, backupDir: URL) throws -> ActionCard? {
        guard let url = resolve(relPath) else { throw FileError.outsideSandbox }
        let exists = FileManager.default.fileExists(atPath: url.path)
        if exists && !overwrite { throw FileError.existsNeedsConfirmation }
        var backupCard: ActionCard? = nil
        if exists {
            try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
            let backupURL = backupDir.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
            try FileManager.default.copyItem(at: url, to: backupURL)
            backupCard = ActionCard(id: UUID(), kind: .backup, title: "Sicherung vor Überschreiben",
                                     detail: backupURL.lastPathComponent, createdAt: Date())
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return backupCard
    }

    func rename(_ relPath: String, to newName: String) throws -> String {
        guard let url = resolve(relPath) else { throw FileError.outsideSandbox }
        guard !newName.contains("/"), newName != "." && newName != ".." else { throw FileError.outsideSandbox }
        guard FileManager.default.fileExists(atPath: url.path) else { throw FileError.notFound }
        let target = url.deletingLastPathComponent().appendingPathComponent(newName)
        guard !FileManager.default.fileExists(atPath: target.path) else { throw FileError.existsNeedsConfirmation }
        do { try FileManager.default.moveItem(at: url, to: target) }
        catch { throw FileError.ioFailure(error.localizedDescription) }
        return relPath(of: target)
    }

    func move(_ relPath: String, toFolder: String) throws -> String {
        guard let url = resolve(relPath) else { throw FileError.outsideSandbox }
        guard let folderURL = resolve(toFolder) else { throw FileError.outsideSandbox }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDir), isDir.boolValue else { throw FileError.notAFolder }
        let target = folderURL.appendingPathComponent(url.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: target.path) else { throw FileError.existsNeedsConfirmation }
        do { try FileManager.default.moveItem(at: url, to: target) }
        catch { throw FileError.ioFailure(error.localizedDescription) }
        return relPath(of: target)
    }
```
- [ ] **Schritt 3: Commit + Push + CI grün** – `git commit -m "feat: write mit Backup, rename, move"`
- [ ] **Schritt 4: Review-Fokus** – Überschreiben ohne Bestätigung wirft `existsNeedsConfirmation` (`testWriteExistiertOhneOverwrite`); Backup-Inhalt verifiziert.

---

### Task 8: SecurityStore – Freigaben + Keychain

**Files:**
- Create: `Sources/Core/SecurityStore.swift`
- Test: `Tests/SecurityStoreTests.swift`

**Interfaces:**
- Consumes: `Grant` (Task 5). Produces: `final class SecurityStore` mit `init(defaults: UserDefaults = .standard)`, `@discardableResult func addGrant(url: URL) throws -> Grant`, `func loadGrants() -> [Grant]` (ungültige Bookmarks werden übersprungen, App stürzt nicht), `func saveKey(_ key: String) throws`, `func loadKey() -> String?`, `func removeKey()`

- [ ] **Schritt 1: Tests schreiben**
```swift
import XCTest
@testable import PadPilot

final class SecurityStoreTests: XCTestCase {
    var store: SecurityStore!
    var defaults: UserDefaults!
    var tmp: URL!

    override func setUp() {
        defaults = UserDefaults(suiteName: UUID().uuidString)
        store = SecurityStore(defaults: defaults)
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: tmp) }

    func testGrantRoundtrip() throws {
        let grant = try store.addGrant(url: tmp)
        XCTAssertEqual(grant.name, tmp.lastPathComponent)
        let loaded = store.loadGrants()
        XCTAssertEqual(loaded.first?.name, grant.name)
    }
    func testKaputtesBookmarkWirdUebersprungen() throws {
        _ = try store.addGrant(url: tmp)
        defaults.set(try JSONEncoder().encode([BookmarkRecord(id: UUID(), name: "Kaputt", data: Data([1, 2, 3])]),
                                              forKey: SecurityStore.storageKey)
        XCTAssertTrue(store.loadGrants().isEmpty)
    }
    func testKeyRoundtrip() throws {
        XCTAssertNil(store.loadKey())
        try store.saveKey("sk-test-123")
        XCTAssertEqual(store.loadKey(), "sk-test-123")
        store.removeKey()
        XCTAssertNil(store.loadKey())
    }
}
```
- [ ] **Schritt 2: Implementierung**
```swift
import Foundation
import Security

struct BookmarkRecord: Codable {
    let id: UUID
    let name: String
    let data: Data
}

final class SecurityStore: @unchecked Sendable {
    static let storageKey = "padpilot.grants"
    private let defaults: UserDefaults
    private let service = "com.padpilot.app"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    @discardableResult
    func addGrant(url: URL) throws -> Grant {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData()
        var records = Self.decode(defaults.data(forKey: Self.storageKey))
        let grant = Grant(id: UUID(), name: url.lastPathComponent, url: url)
        records.append(BookmarkRecord(id: grant.id, name: grant.name, data: data))
        defaults.set(try JSONEncoder().encode(records), forKey: Self.storageKey)
        return grant
    }

    func loadGrants() -> [Grant] {
        var grants: [Grant] = []
        for record in Self.decode(defaults.data(forKey: Self.storageKey)) {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: record.data, relativeTo: nil,
                                     bookmarkDataIsStale: &stale), !stale else { continue }
            _ = url.startAccessingSecurityScopedResource()
            grants.append(Grant(id: record.id, name: record.name, url: url))
        }
        return grants
    }

    private static func decode(_ data: Data?) -> [BookmarkRecord] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([BookmarkRecord].self, from: data)) ?? []
    }

    // MARK: Keychain (Claude-API-Key)
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "claude"]
    }

    func saveKey(_ key: String) throws {
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = Data(key.utf8)
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw ModelError.network("Keychain-Fehler \(status)") }
    }

    func loadKey() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    func removeKey() { SecItemDelete(query as CFDictionary) }
}
```
- [ ] **Schritt 3: Commit + Push + CI grün** – `git commit -m "feat: SecurityStore für Freigaben und Keychain"`
- [ ] **Schritt 4: Review-Fokus** – Verfallene/kaputte Freigabe wird übersprungen statt Crash (`testKaputtesBookmarkWirdUebersprungen`).

---

### Task 9: PadPilotStore – SwiftData-Verlauf

**Files:**
- Create: `Sources/Store/PadPilotStore.swift`
- Test: `Tests/PadPilotStoreTests.swift`

**Interfaces:**
- Produces: `@Model final class StoredSession { id: UUID (unique), createdAt: Date, payload: Data }`, `final class PadPilotStore` mit `init(inMemory: Bool = false) throws`, `func save(sessionID: UUID, messages: [ChatMessage]) throws` (überschreibt existierende Session), `func load(sessionID: UUID) -> [ChatMessage]`

- [ ] **Schritt 1: Tests schreiben**
```swift
import XCTest
@testable import PadPilot

final class PadPilotStoreTests: XCTestCase {
    func testSaveLoadOverwrite() throws {
        let store = try PadPilotStore(inMemory: true)
        let id = UUID()
        try store.save(sessionID: id, messages: [ChatMessage(role: .user, text: "hi")])
        XCTAssertEqual(store.load(sessionID: id).count, 1)
        try store.save(sessionID: id, messages: [
            ChatMessage(role: .user, text: "hi"),
            ChatMessage(role: .assistant, text: "moin")])
        let loaded = store.load(sessionID: id)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.last?.text, "moin")
        XCTAssertEqual(store.load(sessionID: UUID()), [])
    }
}
```
- [ ] **Schritt 2: Implementierung**
```swift
import Foundation
import SwiftData

@Model
final class StoredSession {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var payload: Data

    init(id: UUID, createdAt: Date, payload: Data) {
        self.id = id; self.createdAt = createdAt; self.payload = payload
    }
}

final class PadPilotStore: @unchecked Sendable {
    private let container: ModelContainer

    init(inMemory: Bool = false) throws {
        let cfg = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: StoredSession.self, configurations: cfg)
    }

    func save(sessionID: UUID, messages: [ChatMessage]) throws {
        let ctx = ModelContext(container)
        let payload = try JSONEncoder().encode(messages)
        let existing = try ctx.fetch(FetchDescriptor<StoredSession>()).first { $0.id == sessionID }
        if let existing { existing.payload = payload }
        else { ctx.insert(StoredSession(id: sessionID, createdAt: Date(), payload: payload)) }
        try ctx.save()
    }

    func load(sessionID: UUID) -> [ChatMessage] {
        let ctx = ModelContext(container)
        let existing = (try? ctx.fetch(FetchDescriptor<StoredSession>()))?.first { $0.id == sessionID }
        guard let payload = existing?.payload else { return [] }
        return (try? JSONDecoder().decode([ChatMessage].self, from: payload)) ?? []
    }
}
```
- [ ] **Schritt 3: Commit + Push + CI grün** – `git commit -m "feat: SwiftData-Session-Speicher"`

---

### Task 10: ClaudeClient

**Files:**
- Create: `Sources/Core/Providers/ClaudeClient.swift`
- Test: `Tests/ClaudeClientTests.swift`

**Interfaces:**
- Consumes: Task 3 (Verträge), Task 2 (JSONValue). Produces: `final class ClaudeClient: ModelProvider` mit `init(apiKey: String, model: String = "claude-sonnet-4-5", session: URLSession = .shared)`; wirft `ModelError.unauthorized` bei HTTP 401, `ModelError.network` sonst; `static func parse(_ data: Data) throws -> ProviderResponse`

- [ ] **Schritt 1: Tests schreiben**
```swift
import XCTest
@testable import PadPilot

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let h = MockURLProtocol.handler else { return client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)) }
        do {
            let (status, data) = try h(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class ClaudeClientTests: XCTestCase {
    func makeClient() -> ClaudeClient {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        return ClaudeClient(apiKey: "sk-test", session: URLSession(configuration: cfg))
    }

    func testParseTextUndToolUse() throws {
        let json = """
        {"content": [
            {"type": "text", "text": "Ich suche."},
            {"type": "tool_use", "id": "tu_1", "name": "list_files", "input": {"folder": "Doku"}}
        ]}
        """
        let r = try ClaudeClient.parse(Data(json.utf8))
        XCTAssertEqual(r.text, "Ich suche.")
        XCTAssertEqual(r.toolCalls.count, 1)
        XCTAssertEqual(r.toolCalls[0].name, "list_files")
        XCTAssertEqual(r.toolCalls[0].arguments["folder"]?.stringValue, "Doku")
    }

    func testRequestMitSystemToolsUndVerlauf() async throws {
        MockURLProtocol.handler = { req in
            let body = req.httpBody ?? req.httpBodyStreamData ?? Data()
            let json = try JSONValue.from(data: body)
            XCTAssertEqual(json["model"]?.stringValue, "claude-sonnet-4-5")
            if case .array(let tools)? = json["tools"] { XCTAssertEqual(tools.count, 1) } else { XCTFail("tools fehlen") }
            XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "sk-test")
            XCTAssertEqual(req.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
            return (200, Data(#"{"content": [{"type": "text", "text": "ok"}]}"#.utf8))
        }
        let client = makeClient()
        let r = try await client.respond(system: "s", messages: [.user("hi")],
            tools: [ToolSpec(name: "t", description: "d", inputSchema: .object([:]))])
        XCTAssertEqual(r.text, "ok")
        XCTAssertNotNil(MockURLProtocol.handler)
        MockURLProtocol.handler = nil
    }

    func test401WirftUnauthorized() async {
        MockURLProtocol.handler = { _ in (401, Data()) }
        let client = makeClient()
        do {
            _ = try await client.respond(system: "s", messages: [], tools: [])
            XCTFail("erwartet unauthorized")
        } catch { XCTAssertEqual(error as? ModelError, .unauthorized) }
        MockURLProtocol.handler = nil
    }
}
```
- [ ] **Schritt 2: Implementierung**
```swift
import Foundation

final class ClaudeClient: ModelProvider, @unchecked Sendable {
    let name = "Claude"
    private let apiKey: String
    private let model: String
    private let session: URLSession

    init(apiKey: String, model: String = "claude-sonnet-4-5", session: URLSession = .shared) {
        self.apiKey = apiKey; self.model = model; self.session = session
    }

    func respond(system: String, messages: [ProviderMessage], tools: [ToolSpec]) async throws -> ProviderResponse {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try encodeBody(system: system, messages: messages, tools: tools)
        let data: Data; let resp: URLResponse
        do { (data, resp) = try await session.data(for: req) }
        catch { throw ModelError.network(error.localizedDescription) }
        guard let http = resp as? HTTPURLResponse else { throw ModelError.network("Keine HTTP-Antwort") }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 { throw ModelError.unauthorized }
            throw ModelError.network("HTTP \(http.statusCode)")
        }
        return try Self.parse(data)
    }

    private func encodeBody(system: String, messages: [ProviderMessage], tools: [ToolSpec]) throws -> Data {
        var msgs: [JSONValue] = []
        for m in messages {
            switch m {
            case .user(let t):
                msgs.append(.object(["role": .string("user"), "content": .string(t)]))
            case .assistant(let t, let calls):
                var blocks: [JSONValue] = [.object(["type": .string("text"), "text": .string(t)])]
                for c in calls {
                    blocks.append(.object(["type": .string("tool_use"), "id": .string(c.id),
                                            "name": .string(c.name), "input": c.arguments]))
                }
                msgs.append(.object(["role": .string("assistant"), "content": .array(blocks)]))
            case .toolResult(let id, let content):
                msgs.append(.object(["role": .string("user"), "content": .array([
                    .object(["type": .string("tool_result"), "tool_use_id": .string(id), "content": .string(content)])])]))
            }
        }
        let toolsJSON: [JSONValue] = tools.map {
            .object(["name": .string($0.name), "description": .string($0.description), "input_schema": $0.inputSchema])
        }
        let body: JSONValue = .object([
            "model": .string(model), "max_tokens": .number(4096),
            "system": .string(system), "messages": .array(msgs), "tools": .array(toolsJSON)
        ])
        return try body.data()
    }

    static func parse(_ data: Data) throws -> ProviderResponse {
        let root = try JSONValue.from(data: data)
        var text = ""
        var calls: [ToolCall] = []
        guard case .array(let blocks)? = root["content"] else { return ProviderResponse(text: "", toolCalls: []) }
        for b in blocks {
            switch b["type"]?.stringValue {
            case "text": text += b["text"]?.stringValue ?? ""
            case "tool_use":
                calls.append(ToolCall(id: b["id"]?.stringValue ?? UUID().uuidString,
                                      name: b["name"]?.stringValue ?? "",
                                      arguments: b["input"] ?? .object([:])))
            default: break
            }
        }
        return ProviderResponse(text: text, toolCalls: calls)
    }
}

extension URLRequest {
    var httpBodyStreamData: Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open(); defer { stream.close() }
        var data = Data(); let bufSize = 4096
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buf.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buf, maxLength: bufSize)
            if read <= 0 { break }
            data.append(buf, count: read)
        }
        return data
    }
}
```
- [ ] **Schritt 3: Commit + Push + CI grün** – `git commit -m "feat: ClaudeClient mit Tool-Use-API"`
- [ ] **Schritt 4: Review-Fokus** – 401 → `.unauthorized` getestet; Key nur im Header, nie loggen.

---

### Task 11: AppleSystemModel (on-device)

**Files:**
- Create: `Sources/Core/Providers/AppleSystemModel.swift`
- Test: `Tests/AppleSystemModelTests.swift`

**Interfaces:**
- Consumes: `FileTools`, `ActionCard`, `ModelError`. Produces: `final class AppleSystemModel: ModelProvider` mit `init(fileTools: FileTools, backupDir: URL, onCard: @Sendable (ActionCard) -> Void, confirm: @Sendable (String) async -> Bool)`, `init?()`-Verfügbarkeitsvariante; `nil`/`ModelError.unavailable`, wenn Foundation Models fehlen (CI-Simulator). **Wichtig:** FM führt Werkzeuge selbst aus (im `respond`); Karten fließen über `onCard`.

- [ ] **Schritt 1: Test schreiben**
```swift
import XCTest
import FoundationModels
@testable import PadPilot

final class AppleSystemModelTests: XCTestCase {
    func testAvailabilityGuard() throws {
        if SystemLanguageModel.isAvailable {
            throw XCTSkip("FM verfügbar – Guard-Test gilt nur für Umgebungen ohne Apple Intelligence (CI)")
        }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let model = AppleSystemModel(fileTools: FileTools(roots: [Grant(id: UUID(), name: "D", url: tmp)]),
                                      backupDir: tmp, onCard: { _ in }, confirm: { _ in true })
        XCTAssertNil(model)
    }
}
```
- [ ] **Schritt 2: Implementierung** (exakte FM-API-Signaturen bei der Umsetzung gegen Apple-Doku verifizieren – Signaturdrift zwischen FM-Versionen möglich; CI-Compiler ist die Instanz)
```swift
import Foundation
import FoundationModels

final class AppleSystemModel: ModelProvider, @unchecked Sendable {
    let name = "Apple On-Device"
    private let fileTools: FileTools
    private let backupDir: URL
    private let onCard: @Sendable (ActionCard) -> Void
    private let confirm: @Sendable (String) async -> Bool
    private let backingModel = SystemLanguageModel.default

    init?(fileTools: FileTools, backupDir: URL,
          onCard: @Sendable (ActionCard) -> Void,
          confirm: @Sendable (String) async -> Bool) {
        guard SystemLanguageModel.isAvailable else { return nil }
        self.fileTools = fileTools; self.backupDir = backupDir
        self.onCard = onCard; self.confirm = confirm
    }

    func respond(system: String, messages: [ProviderMessage], tools: [ToolSpec]) async throws -> ProviderResponse {
        guard SystemLanguageModel.isAvailable else { throw ModelError.unavailable }
        let box = ToolBox(fileTools: fileTools, backupDir: backupDir, onCard: onCard, confirm: confirm)
        let session = LanguageModelSession(instructions: Instructions(instructions: system),
                                            tools: [box.listFiles, box.searchFiles, box.readFile,
                                                    box.writeFile, box.renameFile, box.moveFile])
        let prompt = Self.transcript(messages: messages)
        let response = try await session.respond(to: prompt)
        return ProviderResponse(text: response.content, toolCalls: [])
    }

    static func transcript(messages: [ProviderMessage]) -> String {
        messages.map {
            switch $0 {
            case .user(let t): return "Nutzer: \(t)"
            case .assistant(let t, _): return "Agent: \(t)"
            case .toolResult(_, let c): return "Beobachtung: \(c)"
            }
        }.joined(separator: "\n")
    }
}

private final class ToolBox: @unchecked Sendable {
    let fileTools: FileTools
    let backupDir: URL
    let onCard: @Sendable (ActionCard) -> Void
    let confirm: @Sendable (String) async -> Bool

    init(fileTools: FileTools, backupDir: URL,
         onCard: @Sendable (ActionCard) -> Void, confirm: @Sendable (String) async -> Bool) {
        self.fileTools = fileTools; self.backupDir = backupDir
        self.onCard = onCard; self.confirm = confirm
    }

    @GenerableTool(description: "Listet Dateien eines Ordners. folder = relativer Pfad inkl. Freigabe-Name (z. B. 'Doku').")
    func listFiles(folder: String) async -> String {
        do {
            let entries = try fileTools.list(folder: folder)
            onCard(ActionCard(id: UUID(), kind: .list, title: "Ordner gelistet",
                              detail: folder, createdAt: Date()))
            return entries.isEmpty ? "Ordner ist leer."
                : entries.map { $0.isFolder ? "[Ordner] \($0.relPath)" : $0.relPath }.joined(separator: "\n")
        } catch { return "Fehler: \(error)" }
    }

    @GenerableTool(description: "Durchsucht Dateien nach Namen und optional nach Inhalt.")
    func searchFiles(nameContains: String, contentContains: String?) async -> String {
        do {
            let hits = try fileTools.search(nameContains: nameContains, contentContains: contentContains)
            onCard(ActionCard(id: UUID(), kind: .search, title: "Suche: '\(nameContains)'",
                              detail: "\(hits.count) Treffer", createdAt: Date()))
            return hits.map(\.relPath).joined(separator: "\n").isEmpty ? "Keine Treffer."
                : hits.map(\.relPath).joined(separator: "\n")
        } catch { return "Fehler: \(error)" }
    }

    @GenerableTool(description: "Liest den Inhalt einer Datei (Text oder PDF). path = relativer Pfad inkl. Freigabe-Name.")
    func readFile(path: String) async -> String {
        do {
            let text = try fileTools.read(path)
            onCard(ActionCard(id: UUID(), kind: .read, title: "Datei gelesen",
                              detail: path, createdAt: Date()))
            return text
        } catch { return "Fehler: \(error)" }
    }

    @GenerableTool(description: "Erstellt/überschreibt eine Datei. Vor Überschreiben wird der Nutzer gefragt und ein Backup erstellt.")
    func writeFile(path: String, content: String) async -> String {
        do {
            if fileTools.resolve(path).map(FileManager.default.fileExists(atPath:)) == true {
                guard await confirm("Datei '\(path)' überschreiben?") else { return "Nutzer hat Überschreiben abgelehnt." }
            }
            if let card = try fileTools.write(path, content: content, overwrite: true, backupDir: backupDir) {
                onCard(card)
            }
            onCard(ActionCard(id: UUID(), kind: .write, title: "Datei geschrieben",
                              detail: path, createdAt: Date()))
            return "Geschrieben: \(path)"
        } catch { return "Fehler: \(error)" }
    }

    @GenerableTool(description: "Benennt eine Datei um (kein Pfad im neuen Namen).")
    func renameFile(path: String, newName: String) async -> String {
        do {
            let rel = try fileTools.rename(path, to: newName)
            onCard(ActionCard(id: UUID(), kind: .rename, title: "Umbenannt",
                              detail: "\(path) → \(rel)", createdAt: Date()))
            return "Neuer Pfad: \(rel)"
        } catch { return "Fehler: \(error)" }
    }

    @GenerableTool(description: "Verschiebt eine Datei in einen anderen Ordner (innerhalb der Freigaben).")
    func moveFile(path: String, toFolder: String) async -> String {
        do {
            let rel = try fileTools.move(path, toFolder: toFolder)
            onCard(ActionCard(id: UUID(), kind: .move, title: "Verschoben",
                              detail: "\(path) → \(rel)", createdAt: Date()))
            return "Neuer Pfad: \(rel)"
        } catch { return "Fehler: \(error)" }
    }
}
```
- [ ] **Schritt 3: Commit + Push + CI grün** – `git commit -m "feat: On-Device-Provider mit FoundationModels-Tools"`
- [ ] **Schritt 4: Risikenotiz** – FM-API-Signaturen (LanguageModelSession, @GenerableTool, Instructions) beim Umsetzen gegen die Apple-Doku prüfen; falls CI-Compiler abweicht: anpassen, Tests des FileTools bleiben unberührt.

---

### Task 12: AgentRunner

**Files:**
- Create: `Sources/Core/AgentRunner.swift`
- Test: `Tests/AgentRunnerTests.swift`

**Interfaces:**
- Consumes: FileTools, ModelProvider, ActionCard, ChatMessage. Produces: `struct AgentRunner: Sendable` mit `init(provider:, fileTools:, backupDir:, onCard: @Sendable (ActionCard) -> Void, confirm: @Sendable (String) async -> Bool)`, `static let systemPrompt`, `static let toolSpecs: [ToolSpec]`, `func run(userText: String, prior: [ProviderMessage]) async throws -> RunResult`, `enum RunResult { completed(text:, cards:), limitReached(text:, cards:) }`, `static let maxSteps = 15`

- [ ] **Schritt 1: Tests schreiben**
```swift
import XCTest
@testable import PadPilot

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

    private func makeRunner(script: [ProviderResponse], confirm: @Sendable @escaping (String) async -> Bool = { _ in true })
        -> (AgentRunner, FakeProvider, recorder: ActorCards) {
        let cards = ActorCards()
        let fake = FakeProvider(script: script)
        let runner = AgentRunner(provider: fake, fileTools: tools, backupDir: backup,
                                 onCard: { cards.add($0) }, confirm: confirm)
        return (runner, fake, cards)
    }

    actor ActorCards {
        var all: [ActionCard] = []
        func add(_ c: ActionCard) { all.append(c) }
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
        let all = await cards.all
        XCTAssertTrue(all.contains { $0.kind == .list })
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
        let (runner, _, cards) = makeRunner(script: [
            .init(text: "", toolCalls: [
                .init(id: "1", name: "write_file", arguments: .object([
                    "path": .string("Doku/n.txt"), "content": .string("neu"), "overwrite": .bool(false)]))]),
            .init(text: "Ok, nicht geschrieben.", toolCalls: [])
        ], confirm: { _ in false })
        let result = try await runner.run(userText: "Überschreibe n.txt", prior: [])
        guard case .completed(let text, _) = result else { return XCTFail() }
        XCTAssertEqual(text, "Ok, nicht geschrieben.")
        XCTAssertEqual(try tools.read("Doku/n.txt"), "a")
        let all = await cards.all
        XCTAssertTrue(all.contains { $0.kind == .hint })  // Ablehnung als Hinweis
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
```
- [ ] **Schritt 2: Implementierung**
```swift
import Foundation

struct AgentRunner: Sendable {
    static let maxSteps = 15

    let provider: ModelProvider
    let fileTools: FileTools
    let backupDir: URL
    let onCard: @Sendable (ActionCard) -> Void
    let confirm: @Sendable (String) async -> Bool

    init(provider: ModelProvider, fileTools: FileTools, backupDir: URL,
         onCard: @Sendable (ActionCard) -> Void,
         confirm: @Sendable (String) async -> Bool) {
        self.provider = provider; self.fileTools = fileTools; self.backupDir = backupDir
        self.onCard = onCard; self.confirm = confirm
    }

    static let systemPrompt = """
    Du bist PadPilot, ein Datei-Agent auf einem iPad. Du bearbeitest ausschließlich Dateien \
    in den Freigaben des Nutzers. Pfade beginnen immer mit dem Freigabe-Namen, z. B. 'Doku/Notizen/a.md'. \
    Löschen ist nicht erlaubt. Vor dem Überschreiben einer bestehenden Datei fragst du über das \
    Werkzeug write_file (overwrite: false) an und akzeptierst die Entscheidung des Nutzers. \
    Antworte kurz und klar auf Deutsch. Nutze Werkzeuge, statt zu raten.
    """

    static let toolSpecs: [ToolSpec] = [
        ToolSpec(name: "list_files",
                 description: "Listet den Inhalt eines Ordners. 'Doku' allein = Wurzel der Freigabe.",
                 inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object(["folder": .object([
                        "type": .string("string"),
                        "description": .string("Relativer Ordnerpfad inkl. Freigabe-Name")])]),
                    "required": .array([.string("folder")])])),
        ToolSpec(name: "search_files",
                 description: "Sucht Dateien nach Name und optional nach Inhalt.",
                 inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "nameContains": .object(["type": .string("string")]),
                        "contentContains": .object(["type": .string("string")])]),
                    "required": .array([.string("nameContains")])])),
        ToolSpec(name: "read_file",
                 description: "Liest den Inhalt einer Datei (Text oder PDF).",
                 inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object(["path": .object(["type": .string("string")])]),
                    "required": .array([.string("path")])])),
        ToolSpec(name: "write_file",
                 description: "Erstellt oder überschreibt eine Textdatei. overwrite nur true setzen, wenn der Nutzer es erlaubt hat.",
                 inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "path": .object(["type": .string("string")]),
                        "content": .object(["type": .string("string")]),
                        "overwrite": .object(["type": .string("boolean")])]),
                    "required": .array([.string("path"), .string("content")])])),
        ToolSpec(name: "rename_file",
                 description: "Benennt eine Datei um. newName enthält keinen Pfad.",
                 inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "path": .object(["type": .string("string")]),
                        "newName": .object(["type": .string("string")])]),
                    "required": .array([.string("path"), .string("newName")])])),
        ToolSpec(name: "move_file",
                 description: "Verschiebt eine Datei in einen Zielordner.",
                 inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "path": .object(["type": .string("string")]),
                        "toFolder": .object(["type": .string("string")])]),
                    "required": .array([.string("path"), .string("toFolder")])]))
    ]

    enum RunResult: Sendable {
        case completed(text: String, cards: [ActionCard])
        case limitReached(text: String, cards: [ActionCard])
    }

    func run(userText: String, prior: [ProviderMessage]) async throws -> RunResult {
        var messages = prior
        messages.append(.user(userText))
        var produced: [ActionCard] = []
        for _ in 0..<Self.maxSteps {
            let resp = try await provider.respond(system: Self.systemPrompt,
                                                   messages: messages, tools: Self.toolSpecs)
            if resp.toolCalls.isEmpty {
                return .completed(text: resp.text, cards: produced)
            }
            messages.append(.assistant(text: resp.text, toolCalls: resp.toolCalls))
            for call in resp.toolCalls {
                let (obs, cards) = await execute(call)
                produced += cards
                messages.append(.toolResult(id: call.id, content: obs))
            }
        }
        return .limitReached(text: "Werkzeug-Limit (\(Self.maxSteps)) erreicht – Aufgabe abgebrochen.", cards: produced)
    }

    private func execute(_ call: ToolCall) async -> (String, [ActionCard]) {
        let arg = call.arguments
        func str(_ key: String) -> String { arg[key]?.stringValue ?? "" }
        var cards: [ActionCard] = []
        func card(_ kind: CardKind, _ title: String, _ detail: String) {
            let c = ActionCard(id: UUID(), kind: kind, title: title, detail: detail, createdAt: Date())
            cards.append(c); onCard(c)
        }
        do {
            switch call.name {
            case "list_files":
                let entries = try fileTools.list(folder: str("folder"))
                card(.list, "Ordner gelistet", str("folder"))
                return (entries.isEmpty ? "Ordner ist leer."
                        : entries.map { $0.isFolder ? "[Ordner] \($0.relPath)" : $0.relPath }.joined(separator: "\n"), cards)
            case "search_files":
                let hits = try fileTools.search(nameContains: str("nameContains"),
                                               contentContains: str("contentContains").ifEmpty(nil))
                card(.search, "Suche: '\(str("nameContains"))'", "\(hits.count) Treffer")
                return (hits.map(\.relPath).joined(separator: "\n").ifEmpty("Keine Treffer."), cards)
            case "read_file":
                let text = try fileTools.read(str("path"))
                card(.read, "Datei gelesen", str("path"))
                return (text, cards)
            case "write_file":
                let path = str("path")
                let exists = fileTools.resolve(path).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
                let overwrite = arg["overwrite"]?.boolValue ?? false
                if exists && !overwrite {
                    guard await confirm("Datei '\(path)' überschreiben?") else {
                        card(.hint, "Überschreiben abgelehnt", path)
                        return ("Nutzer hat Überschreiben abgelehnt.", cards)
                    }
                }
                if let backupCard = try fileTools.write(path, content: str("content"),
                                                        overwrite: exists, backupDir: backupDir) {
                    onCard(backupCard); cards.append(backupCard)
                }
                card(.write, exists ? "Datei überschrieben" : "Datei geschrieben", path)
                return ("Geschrieben: \(path)", cards)
            case "rename_file":
                let rel = try fileTools.rename(str("path"), to: str("newName"))
                card(.rename, "Umbenannt", "\(str("path")) → \(rel)")
                return ("Neuer Pfad: \(rel)", cards)
            case "move_file":
                let rel = try fileTools.move(str("path"), toFolder: str("toFolder"))
                card(.move, "Verschoben", "\(str("path")) → \(rel)")
                return ("Neuer Pfad: \(rel)", cards)
            default:
                return ("Unbekanntes Werkzeug: \(call.name)", cards)
            }
        } catch {
            card(.error, "Werkzeugfehler", "\(call.name): \(error)")
            return ("Fehler: \(error)", cards)
        }
    }
}

private extension String {
    func ifEmpty(_ other: String?) -> String? { isEmpty ? other : self }
}
```
Hinweis: `write` erhält `overwrite: exists`, weil der Bestätigungsfall oben bereits abgehandelt wurde; `confirm` ist async, weil die UI-Brücke (Task 13) auf den Nutzer-Dialog wartet.
- [ ] **Schritt 3: Commit + Push + CI grün** – `git commit -m "feat: AgentRunner mit Loop, Limit und Bestätigungsgate"`
- [ ] **Schritt 4: Review-Fokus** – Endlosloop → `limitReached` (`testWerkzeuglimit`); abgelehnte Bestätigung → Datei unverändert (`testBestaetigungAbgelehnt`); Fehler → Beobachtung statt Absturz (`testFehlerWirdBeobachtung`).

---

### Task 13: ChatViewModel

**Files:**
- Create: `Sources/UI/ChatViewModel.swift`
- Test: `Tests/ChatViewModelTests.swift`

**Interfaces:**
- Consumes: AgentRunner, AppleSystemModel, ClaudeClient, SecurityStore, PadPilotStore, ChatMessage. Produces: `@MainActor @Observable final class ChatViewModel` mit `enum Mode: String, Codable { auto, onDevice, claude }`, `var messages: [ChatMessage]`, `var status: Status { idle, thinking, error(String) }`, `var mode: Mode`, `var grants: [Grant]`, `var draft: String`, `var pendingConfirmation: Confirmation?`, `func load()`, `func addGrant(url: URL)`, `func saveKey(_ key: String)`, `func run(_ text: String)` (startet internen Task), `func waitForRunEnd() async`, `func resolveConfirmation(_ allowed: Bool)`, `struct Confirmation: Identifiable { id, prompt }`. Init (testbar): `init(security: SecurityStore = SecurityStore(), store: PadPilotStore? = nil, makeProvider: ((Mode) throws -> ModelProvider)? = nil)` – Ohne injizierte Factory baut das VM echte Provider (AppleSystemModel/ClaudeClient mit Key aus dem Keychain)

- [ ] **Schritt 1: Tests schreiben**
```swift
import XCTest
@testable import PadPilot

@MainActor
final class ChatViewModelTests: XCTestCase {
    func makeVM(makeProvider: @escaping (ChatViewModel.Mode) throws -> ModelProvider) throws -> ChatViewModel {
        ChatViewModel(store: try PadPilotStore(inMemory: true), makeProvider: makeProvider)
    }

    func testRunHaengtAntwortAn() async throws {
        let fake = FakeProvider(script: [.init(text: "Erledigt", toolCalls: [])])
        let vm = try makeVM { _ in fake }
        vm.run("test")
        await vm.waitForRunEnd()
        XCTAssertEqual(vm.messages.first?.role, .user)
        XCTAssertEqual(vm.messages.last?.text, "Erledigt")
        XCTAssertEqual(vm.status, .idle)
    }

    func testAutoEskaliertBeiUnavailable() async throws {
        let claude = FakeProvider(script: [.init(text: "via Claude", toolCalls: [])])
        let vm = try makeVM { mode in
            if mode == .onDevice { throw ModelError.unavailable }
            return claude
        }
        vm.mode = .auto
        vm.run("mach was")
        await vm.waitForRunEnd()
        XCTAssertEqual(vm.messages.last?.text, "via Claude")
        let assistant = vm.messages.last!
        XCTAssertTrue(assistant.cards.contains { $0.kind == .hint })
    }

    func testVerlaufWirdGespeichert() async throws {
        let fake = FakeProvider(script: [.init(text: "ok", toolCalls: [])])
        let store = try PadPilotStore(inMemory: true)
        let vm = ChatViewModel(store: store, makeProvider: { _ in fake })
        vm.run("hallo")
        await vm.waitForRunEnd()
        let loaded = store.load(sessionID: vm.sessionID)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.last?.text, "ok")
    }

    func testBestaetigungsBruecke() async throws {
        let fake = FakeProvider(script: [
            .init(text: "", toolCalls: [.init(id: "1", name: "write_file",
                arguments: .object(["path": .string("D/exists.txt"), "content": .string("x")]))]),
            .init(text: "fertig", toolCalls: [])
        ])
        let vm = try makeVM { _ in fake }
        vm.run("schreibe")
        while vm.pendingConfirmation == nil { await Task.yield() }   // Run wartet auf Bestätigung
        XCTAssertTrue(vm.pendingConfirmation?.prompt.contains("exists.txt") == true)
        vm.resolveConfirmation(false)
        await vm.waitForRunEnd()
        XCTAssertEqual(vm.messages.last?.text, "fertig")
    }
}
```
- [ ] **Schritt 2: Implementierung**
```swift
import SwiftUI
import Observation

@MainActor
final class ChatViewModel {
    enum Mode: String, Codable { case auto, onDevice, claude }
    enum Status: Equatable { case idle, thinking, error(String) }

    struct Confirmation: Identifiable {
        let id = UUID()
        let prompt: String
        var continuation: CheckedContinuation<Bool, Never>?
    }

    let sessionID = UUID()
    var messages: [ChatMessage] = []
    var status: Status = .idle
    var mode: Mode = .auto
    var grants: [Grant] = []
    var draft = ""
    var pendingConfirmation: Confirmation?

    private let security: SecurityStore
    private let store: PadPilotStore?
    private let makeProvider: (Mode) throws -> ModelProvider
    private var runTask: Task<Void, Never>?
    private var activeCards: ActorCardCollector?

    init(security: SecurityStore = SecurityStore(),
         store: PadPilotStore? = nil,
         makeProvider: ((Mode) throws -> ModelProvider)? = nil) {
        self.security = security
        self.store = store
        self.makeProvider = makeProvider ?? { [weak self] mode in
            guard let self else { throw ModelError.network("ViewModel nicht mehr verfügbar") }
            switch mode {
            case .onDevice:
                guard let onDevice = AppleSystemModel(fileTools: self.fileTools(),
                                                     backupDir: self.backupDir,
                                                     onCard: { self.activeCards?.add($0) },
                                                     confirm: self.confirmBridge) else {
                    throw ModelError.unavailable
                }
                return onDevice
            case .claude, .auto:
                guard let key = self.security.loadKey() else { throw ModelError.unauthorized }
                return ClaudeClient(apiKey: key)
            }
        }
    }

    func load() {
        grants = security.loadGrants()
        if let store { messages = store.load(sessionID: sessionID) }
    }

    func addGrant(url: URL) {
        do { _ = try security.addGrant(url: url); grants = security.loadGrants() }
        catch { status = .error("Freigabe fehlgeschlagen: \(error)") }
    }

    func saveKey(_ key: String) {
        do { try security.saveKey(key) } catch { status = .error("Key speichern fehlgeschlagen: \(error)") }
    }

    private var backupDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(".backups")
    }

    private func fileTools() -> FileTools {
        FileTools(roots: security.loadGrants())
    }

    func run(_ text: String) {
        let prior = priorProviderMessages()
        messages.append(ChatMessage(role: .user, text: text))
        status = .thinking
        runTask = Task { [weak self] in
            guard let self else { return }
            await self.executeRun(text: text, prior: prior)
        }
    }

    func waitForRunEnd() async {
        await runTask?.value
    }

    private func executeRun(text: String, prior: [ProviderMessage]) async {
        var allCards: [ActionCard] = []
        do {
            let (provider, hint) = try resolveProvider()
            if let hint { allCards.append(hint) }
            let cards = ActorCardCollector()
            activeCards = cards
            let runner = AgentRunner(provider: provider, fileTools: fileTools(), backupDir: backupDir,
                                     onCard: { cards.add($0) }, confirm: confirmBridge)
            let result = try await runner.run(userText: text, prior: prior)
            allCards += await cards.all
            let finalText: String
            switch result {
            case .completed(let t, _): finalText = t
            case .limitReached(let t, _): finalText = t
            }
            messages.append(ChatMessage(role: .assistant, text: finalText, cards: allCards))
            status = .idle
        } catch {
            allCards.append(ActionCard(id: UUID(), kind: .error, title: "Fehler", detail: "\(error)", createdAt: Date()))
            messages.append(ChatMessage(role: .assistant, text: errorText(error), cards: allCards))
            status = .idle
        }
        if let store { try? store.save(sessionID: sessionID, messages: messages) }
    }

    private func resolveProvider() throws -> (ModelProvider, ActionCard?) {
        switch mode {
        case .onDevice:
            return (try makeProvider(.onDevice), nil)
        case .claude:
            return (try makeProvider(.claude), nil)
        case .auto:
            do { return (try makeProvider(.onDevice), nil) }
            catch {
                let hint = ActionCard(id: UUID(), kind: .hint, title: "On-Device nicht möglich, wechsle zu Claude",
                                      detail: "\(error)", createdAt: Date())
                return (try makeProvider(.claude), hint)
            }
        }
    }

    private lazy var confirmBridge: @Sendable (String) async -> Bool = { [weak self] prompt in
        await MainActor.run {
            await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
                self?.pendingConfirmation = Confirmation(prompt: prompt, continuation: c)
            }
        }
    }

    private func errorText(_ error: Error) -> String {
        switch error as? ModelError {
        case .unauthorized: return "Claude-API-Key ungültig – bitte in den Einstellungen prüfen. On-Device-Modus bleibt nutzbar."
        case .network(let msg): return "Netzwerkfehler: \(msg). On-Device-Modus bleibt nutzbar."
        case .unavailable: return "On-Device-Modell nicht verfügbar."
        case nil: return "Fehler: \(error)"
        }
    }

    private func priorProviderMessages() -> [ProviderMessage] {
        messages.flatMap { m -> [ProviderMessage] in
            switch m.role {
            case .user: return [.user(m.text)]
            case .assistant:
                let actions = m.cards.filter { $0.kind != .error }.map { "\($0.kind.rawValue): \($0.title)" }
                let t = m.text + (actions.isEmpty ? "" : "\n[Aktionen: \(actions.joined(separator: "; "))]")
                return [.assistant(text: t, toolCalls: [])]
            case .system: return []
            }
        }
    }

    func resolveConfirmation(_ allowed: Bool) {
        pendingConfirmation?.continuation?.resume(returning: allowed)
        pendingConfirmation = nil
    }
}

actor ActorCardCollector {
    var all: [ActionCard] = []
    func add(_ c: ActionCard) { all.append(c) }
}
```
Hinweis: `ActorCardCollector` ist ein `actor` – Kartenzuwachs aus Werkzeug-Rückrufen ist datenrennen-sicher (Swift 6 Strict Concurrency).
- [ ] **Schritt 3: Commit + Push + CI grün** – `git commit -m "feat: ChatViewModel mit Auto-Eskalation und Bestätigungsbrücke"`
- [ ] **Schritt 4: Review-Fokus** – Claude 401/offline → Nutzer-Meldung + on-device bleibt nutzbar (`testAutoEskaliertBeiUnavailable` deckt Eskalation ab; Fehlertext-Mapping prüfen).

---

### Task 14: UI + Installations-Verfeinerung

**Files:**
- Modify: `Sources/UI/ChatView.swift` (Platzhalter ersetzen)
- Create: `Sources/UI/ActionCardView.swift`, `Sources/UI/SettingsView.swift`, `Sources/UI/FolderPicker.swift`, `Sources/UI/MessageBubble.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: ChatViewModel (Task 13), SecurityStore. Produces: installierbare App mit Chat, Karten, Bestätigungsdialog, Ordner-Freigabe, Key-Eingabe, Modus-Picker.

- [ ] **Schritt 1: Views schreiben**

`Sources/UI/MessageBubble.swift`:
```swift
import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
            if !message.text.isEmpty {
                Text(message.text).padding(10)
                    .background(message.role == .user ? Color.blue.opacity(0.15) : Color.gray.opacity(0.12))
                    .cornerRadius(12)
            }
            ForEach(message.cards) { ActionCardView(card: $0) }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .padding(.horizontal)
    }
}
```

`Sources/UI/ActionCardView.swift`:
```swift
import SwiftUI

struct ActionCardView: View {
    let card: ActionCard
    private var symbol: String {
        switch card.kind {
        case .list: "list.bullet"; case .search: "magnifyingglass"; case .read: "doc.text"
        case .write: "square.and.pencil"; case .rename: "pencil"; case .move: "arrow.uturn.right"
        case .backup: "externaldrive"; case .error: "exclamationmark.triangle"; case .hint: "info.circle"
        }
    }
    var body: some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(card.kind == .error ? .red : .accent)
            VStack(alignment: .leading) {
                Text(card.title).font(.footnote).bold()
                Text(card.detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(8).background(.gray.opacity(0.08)).cornerRadius(8)
    }
}
```

`Sources/UI/FolderPicker.swift`:
```swift
import SwiftUI
import UniformTypeIdentifiers

struct FolderPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }
    }
}
```

`Sources/UI/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    @State private var vm: SettingsViewModel
    @State private var keyInput = ""
    @State private var showPicker = false

    init(vm: ChatViewModel) { _vm = State(initialValue: SettingsViewModel(vm: vm)) }

    var body: some View {
        Form {
            Section("KI-Modus") {
                Picker("Modus", selection: $vm.mode) {
                    Text("Automatisch").tag(ChatViewModel.Mode.auto)
                    Text("Nur on-device").tag(ChatViewModel.Mode.onDevice)
                    Text("Nur Claude").tag(ChatViewModel.Mode.claude)
                }
            }
            Section("Freigegebene Ordner") {
                ForEach(vm.grants) { Text($0.name).font(.body) }
                Button("Ordner freigeben…") { showPicker = true }
            }
            Section("Claude API-Key") {
                SecureField("sk-ant-…", text: $keyInput)
                Button("Speichern") { vm.saveKey(keyInput) }
                Text("Der Key bleibt nur im iPad-Schlüsselbund (Keychain).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text("Kostenloser Apple-Account: App läuft 7 Tage, dann neu per Sideloadly installieren.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Einstellungen")
        .sheet(isPresented: $showPicker) {
            FolderPicker { vm.addGrant(url: $0) }
        }
    }
}

@Observable @MainActor
final class SettingsViewModel {
    let vm: ChatViewModel
    var mode: ChatViewModel.Mode { get { vm.mode } set { vm.mode = newValue } }
    var grants: [Grant] { vm.grants }
    init(vm: ChatViewModel) { self.vm = vm }
    func addGrant(url: URL) { vm.addGrant(url: url) }
    func saveKey(_ key: String) { vm.saveKey(key) }
}
```
(Bindungshilfe: `SettingsViewModel` leitet bewusst an `ChatViewModel` weiter – ein Klon des Zustands wäre ein Bug-Herd. `$vm.mode` mit `@Bindable` alternativ zulässig.)

`Sources/UI/ChatView.swift` (ersetzen):
```swift
import SwiftUI

struct ChatView: View {
    @State private var vm = ChatViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack {
                        ForEach(vm.messages) { MessageBubble(message: $0) }
                        if vm.status == .thinking {
                            HStack { ProgressView(); Text("Agent arbeitet…") }.padding()
                        }
                    }
                    .padding(.vertical)
                }
                if vm.grants.isEmpty {
                    Label("Kein Ordner freigegeben – Agent kann nichts tun.",
                          systemImage: "folder.badge.questionmark")
                        .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 4)
                }
                HStack(spacing: 8) {
                    TextField("Auftrag…", text: $vm.draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(1...4)
                        .onSubmit { send() }
                    Button { send() } label: { Image(systemName: "paperplane.fill") }
                        .disabled(vm.draft.isEmpty || vm.status == .thinking)
                }
                .padding()
            }
            .navigationTitle("PadPilot")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings) { NavigationStack { SettingsView(vm: vm) } }
            .alert(item: $vm.pendingConfirmation) { conf in
                Alert(title: Text("Überschreiben?"),
                      message: Text(conf.prompt),
                      primaryButton: .destructive(Text("Erlauben")) { vm.resolveConfirmation(true) },
                      secondaryButton: .cancel(Text("Abbrechen")) { vm.resolveConfirmation(false) })
            }
            .onAppear { vm.load() }
        }
    }

    private func send() {
        let text = vm.draft
        vm.draft = ""
        vm.run(text)
    }
}
```

- [ ] **Schritt 2: README ergänzen** – Nutzung: erster Start (Key + Ordner), Beispiel-Aufträge, Bestätigungsdialog erklären
- [ ] **Schritt 3: Commit + Push + CI grün** – `git commit -m "feat: Chat-UI mit Karten, Freigabe und Bestätigungsdialog"`
- [ ] **Schritt 4: Nutzer-Handschritt** – Artifact `PadPilot-unsigned.ipa` aus CI laden, per Sideloadly installieren, Profil vertrauen, Smoke-Test laut README-Checkliste (App startet, Key speichern, Ordner freigeben, Auftrag „Liste die Dateien" läuft)

---

## Selbst-Check des Plans (writing-plans Self-Review)

1. **Spec-Abdeckung:** Chat ✓ (T13/14), Ordner-Freigabe ✓ (T8/14), Datei-Werkzeuge ✓ (T5–7), kein Löschen ✓ (kein Werkzeug), Überschreiben nur mit Bestätigung + Backup ✓ (T7/12/13/14), Aktionskarten ✓ (T4/12/14), Hybrid-KI + Auto-Eskalation ✓ (T11/13), Verlauf ✓ (T9/13), Keychain ✓ (T8/14), CI/IPA ✓ (T1/14), Roadmap-Phasen außerhalb des MVP ✓.
2. **Platzhalter:** keiner; bewusste Stellschrauben (Runner-Image, Simulator-Name, FM-Signaturen) sind als solche markiert und haben Prüf-Schritte.
3. **Typ-Konsistenz:** `FileTools.write` heißt überall gleich; `Confirmation.continuation` (T13) ↔ ChatView `.alert` (T14); `AgentRunner.confirm` ist `(String) -> Bool` (VM macht `await MainActor.run`-Brücke) – konsistent zwischen T12/T13.
4. **Review-Fokus:** Pfad-Flucht (T5), Überschreiben (T7/12/13), Loop (T12), Bookmark-Verfall (T8), 401/offline (T10/13) – jeweils mit Test verankert.
```
