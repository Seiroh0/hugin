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

/// Bestätigungs-Anfrage des Runners an die UI: Pfad + alt/neu für die Diff-Vorschau
struct ConfirmRequest: Sendable, Equatable {
    let path: String
    let oldContent: String?
    let newContent: String
}

protocol ModelProvider: Sendable {
    var name: String { get }
    /// Glut (.local) oder Frost (.claude) – steuert Karten-, Knoten- und Wisp-Farbe
    var actor: Actor { get }
    func respond(system: String, messages: [ProviderMessage], tools: [ToolSpec]) async throws -> ProviderResponse
}

final class FakeProvider: ModelProvider, @unchecked Sendable {
    let name = "Fake"
    let actor: Actor
    private let script: [ProviderResponse]
    private(set) var received: [(system: String, messages: [ProviderMessage], tools: [ToolSpec])] = []
    private var calls = 0
    init(script: [ProviderResponse], actor: Actor = .local) {
        self.script = script; self.actor = actor
    }
    func respond(system: String, messages: [ProviderMessage], tools: [ToolSpec]) async throws -> ProviderResponse {
        received.append((system, messages, tools))
        let r = script[min(calls, script.count - 1)]
        calls += 1
        return r
    }
}
