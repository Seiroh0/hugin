import Foundation
import FoundationModels

final class AppleSystemModel: ModelProvider, @unchecked Sendable {
    let name = "Apple On-Device"
    let actor: Actor = .local   // Glut
    private let fileTools: FileTools
    private let backupDir: URL
    private let onCard: @Sendable (ActionCard) -> Void
    private let onFinding: @Sendable (Finding) -> Void
    private let confirm: @Sendable (ConfirmRequest) async -> Bool

    init?(fileTools: FileTools, backupDir: URL,
          onCard: @Sendable (ActionCard) -> Void,
          onFinding: @Sendable (Finding) -> Void,
          confirm: @Sendable (ConfirmRequest) async -> Bool) {
        // API-Abweichung ggü. Brief: isAvailable ist Instanz-Eigenschaft von
        // SystemLanguageModel.default (Apple-Doku), nicht statisch am Typ.
        guard SystemLanguageModel.default.isAvailable else { return nil }
        self.fileTools = fileTools; self.backupDir = backupDir
        self.onCard = onCard; self.onFinding = onFinding; self.confirm = confirm
    }

    func respond(system: String, messages: [ProviderMessage], tools: [ToolSpec]) async throws -> ProviderResponse {
        guard SystemLanguageModel.default.isAvailable else { throw ModelError.unavailable }
        let box = ToolBox(fileTools: fileTools, backupDir: backupDir, onCard: onCard,
                          onFinding: onFinding, confirm: confirm)
        // API-Abweichung ggü. Brief: Instructions(instructions:) existiert nicht;
        // die Session nimmt den String direkt (Apple-Doku-Überladung), Parameter-
        // reihenfolge laut Deklaration model:tools:instructions:.
        let session = LanguageModelSession(tools: [
            ListFilesTool(box: box), SearchFilesTool(box: box), ReadFileTool(box: box),
            WriteFileTool(box: box), RenameFileTool(box: box), MoveFileTool(box: box),
            NoteFindingTool(box: box)
        ], instructions: system)
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

/// Geteilte Werkzeug-Logik (1:1-Pass-Through zu den getesteten FileTools).
/// API-Abweichung ggü. Brief: @GenerableTool existiert nicht im FoundationModels-
/// Framework (Apple-Doku 404); die Werkzeuge sind daher Tool-Protokoll-Strukturen
/// (Apple-Doku-Muster), die an diese Methoden delegieren.
private final class ToolBox: @unchecked Sendable {
    let fileTools: FileTools
    let backupDir: URL
    private let onCard: @Sendable (ActionCard) -> Void
    private let onFinding: @Sendable (Finding) -> Void
    private let confirm: @Sendable (ConfirmRequest) async -> Bool

    init(fileTools: FileTools, backupDir: URL,
         onCard: @Sendable (ActionCard) -> Void,
         onFinding: @Sendable (Finding) -> Void,
         confirm: @Sendable (ConfirmRequest) async -> Bool) {
        self.fileTools = fileTools; self.backupDir = backupDir
        self.onCard = onCard; self.onFinding = onFinding; self.confirm = confirm
    }

    private func emit(_ kind: CardKind, _ title: String, _ detail: String, since t0: Date) {
        onCard(ActionCard(id: UUID(), kind: kind, actor: .local, title: title, detail: detail,
                          durationMS: Int(Date().timeIntervalSince(t0) * 1000), createdAt: Date()))
    }

    func listFiles(folder: String) async -> String {
        let t0 = Date()
        do {
            let entries = try fileTools.list(folder: folder)
            emit(.list, "Ordner gelistet", folder, since: t0)
            return entries.isEmpty ? "Ordner ist leer."
                : entries.map { $0.isFolder ? "[Ordner] \($0.relPath)" : $0.relPath }.joined(separator: "\n")
        } catch { return "Fehler: \(error)" }
    }

    func searchFiles(nameContains: String, contentContains: String?) async -> String {
        let t0 = Date()
        do {
            let hits = try fileTools.search(nameContains: nameContains, contentContains: contentContains)
            emit(.search, "Suche: '\(nameContains)'", "\(hits.count) Treffer", since: t0)
            return hits.map(\.relPath).joined(separator: "\n").isEmpty ? "Keine Treffer."
                : hits.map(\.relPath).joined(separator: "\n")
        } catch { return "Fehler: \(error)" }
    }

    func readFile(path: String) async -> String {
        let t0 = Date()
        do {
            let text = try fileTools.read(path)
            emit(.read, "Datei gelesen", path, since: t0)
            return text
        } catch { return "Fehler: \(error)" }
    }

    func writeFile(path: String, content: String) async -> String {
        let t0 = Date()
        do {
            let exists = fileTools.resolve(path).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            if exists {
                let old = try? fileTools.read(path)
                let request = ConfirmRequest(path: path, oldContent: old, newContent: content)
                guard await confirm(request) else { return "Nutzer hat Überschreiben abgelehnt." }
            }
            if let card = try fileTools.write(path, content: content, overwrite: exists, backupDir: backupDir) {
                onCard(card)
            }
            emit(.write, exists ? "Datei überschrieben" : "Datei geschrieben", path, since: t0)
            return "Geschrieben: \(path)"
        } catch { return "Fehler: \(error)" }
    }

    func renameFile(path: String, newName: String) async -> String {
        let t0 = Date()
        do {
            let rel = try fileTools.rename(path, to: newName)
            emit(.rename, "Umbenannt", "\(path) → \(rel)", since: t0)
            return "Neuer Pfad: \(rel)"
        } catch { return "Fehler: \(error)" }
    }

    func moveFile(path: String, toFolder: String) async -> String {
        let t0 = Date()
        do {
            let rel = try fileTools.move(path, toFolder: toFolder)
            emit(.move, "Verschoben", "\(path) → \(rel)", since: t0)
            return "Neuer Pfad: \(rel)"
        } catch { return "Fehler: \(error)" }
    }

    func noteFinding(name: String, value: String) async -> String {
        onFinding(Finding(id: UUID(), name: name, value: value, actor: .local, createdAt: Date()))
        return "Notiert: \(name) = \(value)"
    }
}

// MARK: - Werkzeuge (Tool-Protokoll gemäß Apple-Doku statt @GenerableTool)

private struct ListFilesTool: Tool {
    let box: ToolBox
    let name = "listFiles"
    let description = "Listet Dateien eines Ordners. folder = relativer Pfad inkl. Freigabe-Name (z. B. 'Doku')."
    @Generable struct Arguments {
        @Guide(description: "Relativer Pfad inkl. Freigabe-Name, z. B. 'Doku'")
        let folder: String
    }
    func call(arguments: Arguments) async throws -> String {
        await box.listFiles(folder: arguments.folder)
    }
}

private struct SearchFilesTool: Tool {
    let box: ToolBox
    let name = "searchFiles"
    let description = "Durchsucht Dateien nach Namen und optional nach Inhalt."
    @Generable struct Arguments {
        @Guide(description: "Teil des Dateinamens")
        let nameContains: String
        @Guide(description: "Optional: Teilstring, der im Dateiinhalt vorkommen soll")
        let contentContains: String?
    }
    func call(arguments: Arguments) async throws -> String {
        await box.searchFiles(nameContains: arguments.nameContains, contentContains: arguments.contentContains)
    }
}

private struct ReadFileTool: Tool {
    let box: ToolBox
    let name = "readFile"
    let description = "Liest den Inhalt einer Datei (Text oder PDF). path = relativer Pfad inkl. Freigabe-Name."
    @Generable struct Arguments {
        @Guide(description: "Relativer Pfad inkl. Freigabe-Name")
        let path: String
    }
    func call(arguments: Arguments) async throws -> String {
        await box.readFile(path: arguments.path)
    }
}

private struct WriteFileTool: Tool {
    let box: ToolBox
    let name = "writeFile"
    let description = "Erstellt/überschreibt eine Datei. Vor Überschreiben wird der Nutzer gefragt und ein Backup erstellt."
    @Generable struct Arguments {
        @Guide(description: "Relativer Pfad inkl. Freigabe-Name")
        let path: String
        @Guide(description: "Der neue Dateiinhalt")
        let content: String
    }
    func call(arguments: Arguments) async throws -> String {
        await box.writeFile(path: arguments.path, content: arguments.content)
    }
}

private struct RenameFileTool: Tool {
    let box: ToolBox
    let name = "renameFile"
    let description = "Benennt eine Datei um (kein Pfad im neuen Namen)."
    @Generable struct Arguments {
        @Guide(description: "Relativer Pfad inkl. Freigabe-Name")
        let path: String
        @Guide(description: "Neuer Dateiname ohne Pfad")
        let newName: String
    }
    func call(arguments: Arguments) async throws -> String {
        await box.renameFile(path: arguments.path, newName: arguments.newName)
    }
}

private struct MoveFileTool: Tool {
    let box: ToolBox
    let name = "moveFile"
    let description = "Verschiebt eine Datei in einen anderen Ordner (innerhalb der Freigaben)."
    @Generable struct Arguments {
        @Guide(description: "Relativer Pfad inkl. Freigabe-Name")
        let path: String
        @Guide(description: "Zielordner innerhalb der Freigaben")
        let toFolder: String
    }
    func call(arguments: Arguments) async throws -> String {
        await box.moveFile(path: arguments.path, toFolder: arguments.toFolder)
    }
}

private struct NoteFindingTool: Tool {
    let box: ToolBox
    let name = "noteFinding"
    let description = "Meldet einen gefundenen Wert (Beträge, Namen, Daten) für das Fundstück-Panel."
    @Generable struct Arguments {
        @Guide(description: "Kurzname des Fundstücks, z. B. 'Rechnungsbetrag'")
        let name: String
        @Guide(description: "Der gefundene Wert als Text")
        let value: String
    }
    func call(arguments: Arguments) async throws -> String {
        await box.noteFinding(name: arguments.name, value: arguments.value)
    }
}
