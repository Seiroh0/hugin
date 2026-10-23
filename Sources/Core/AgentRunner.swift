import Foundation

struct AgentRunner: Sendable {
    static let maxSteps = 15

    let provider: ModelProvider
    let fileTools: FileTools
    let backupDir: URL
    let onCard: @Sendable (ActionCard) -> Void
    let onFinding: @Sendable (Finding) -> Void
    let confirm: @Sendable (ConfirmRequest) async -> Bool

    init(provider: ModelProvider, fileTools: FileTools, backupDir: URL,
         onCard: @Sendable (ActionCard) -> Void,
         onFinding: @Sendable (Finding) -> Void,
         confirm: @Sendable (ConfirmRequest) async -> Bool) {
        self.provider = provider; self.fileTools = fileTools; self.backupDir = backupDir
        self.onCard = onCard; self.onFinding = onFinding; self.confirm = confirm
    }

    static let systemPrompt = """
    Du bist Hugin, ein Datei-Agent auf einem iPad. Du bearbeitest ausschließlich Dateien \
    in den Freigaben des Nutzers. Pfade beginnen immer mit dem Freigabe-Namen, z. B. 'Doku/Notizen/a.md'. \
    Löschen ist nicht erlaubt. Das Überschreiben bestehender Dateien bestätigt der Nutzer in einem \
    Dialog – akzeptiere seine Entscheidung ohne Nachfragen. \
    Melde gefundene Werte (Beträge, Namen, Daten) mit note_finding – sie erscheinen live im Fundstück-Panel. \
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
                    "required": .array([.string("path"), .string("toFolder")])])),
        ToolSpec(name: "note_finding",
                 description: "Meldet einen gefundenen Wert (Beträge, Namen, Daten) für das Fundstück-Panel.",
                 inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "name": .object(["type": .string("string")]),
                        "value": .object(["type": .string("string")])]),
                    "required": .array([.string("name"), .string("value")])]))
    ]

    enum RunResult: Sendable {
        case completed(text: String, cards: [ActionCard])
        case limitReached(text: String, cards: [ActionCard])
    }

    func run(userText: String, prior: [ProviderMessage]) async throws -> RunResult {
        var messages = prior
        messages.append(.user(userText))
        var produced: [ActionCard] = []
        var performedCalls = 0
        while performedCalls < Self.maxSteps {
            try Task.checkCancellation()   // „Anhalten“ von der UI
            let resp = try await provider.respond(system: Self.systemPrompt,
                                                   messages: messages, tools: Self.toolSpecs)
            if resp.toolCalls.isEmpty {
                return .completed(text: resp.text, cards: produced)
            }
            // Batch kappen, damit das Aufruf-Limit ein hartes Cap bleibt
            let batch = Array(resp.toolCalls.prefix(Self.maxSteps - performedCalls))
            performedCalls += batch.count
            messages.append(.assistant(text: resp.text, toolCalls: batch))
            for call in batch {
                let (obs, cards) = await execute(call)
                produced += cards
                messages.append(.toolResult(id: call.id, content: obs))
            }
        }
        return .limitReached(text: "Werkzeug-Limit (\(Self.maxSteps)) erreicht – Aufgabe abgebrochen.", cards: produced)
    }

    private func execute(_ call: ToolCall) async -> (String, [ActionCard]) {
        let t0 = Date()
        let arg = call.arguments
        func str(_ key: String) -> String { arg[key]?.stringValue ?? "" }
        var cards: [ActionCard] = []
        func card(_ kind: CardKind, _ title: String, _ detail: String) {
            let c = ActionCard(id: UUID(), kind: kind, actor: provider.actor, title: title, detail: detail,
                               durationMS: Int(Date().timeIntervalSince(t0) * 1000), createdAt: Date())
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
                // Gate hängt NIE am LLM-Argument 'overwrite': Jede existierende Datei wird
                // bestätigt (Prompt-Injection-Schutz); ConfirmRequest liefert alt/neu für den Diff
                if exists {
                    let old = try? fileTools.read(path)
                    let request = ConfirmRequest(path: path, oldContent: old, newContent: str("content"))
                    guard await confirm(request) else {
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
            case "note_finding":
                let finding = Finding(id: UUID(), name: str("name"), value: str("value"),
                                      actor: provider.actor, createdAt: Date())
                onFinding(finding)
                return ("Notiert: \(finding.name) = \(finding.value)", cards)
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

/// Karten-Speicher ohne async – Mutex statt Actor, damit synchrone onCard-Closures nutzbar bleiben
/// (falls `Synchronization` im Ziel-SDK fehlt: DispatchQueue-Lock als Ersatz)
import Synchronization

final class CardBuffer: @unchecked Sendable {
    private let mutex = Mutex<[ActionCard]>([])
    func add(_ card: ActionCard) { mutex.withLock { $0.append(card) } }
    var all: [ActionCard] { mutex.withLock { $0 } }
}

final class FindingBuffer: @unchecked Sendable {
    private let mutex = Mutex<[Finding]>([])
    func add(_ f: Finding) { mutex.withLock { $0.append(f) } }
    var all: [Finding] { mutex.withLock { $0 } }
}
