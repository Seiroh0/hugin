import Foundation

enum Role: String, Codable, Sendable { case user, assistant, system }

/// „Farbe sagt, wer denkt": .local = Glut (on-device), .claude = Frost (Cloud)
enum Actor: String, Codable, Sendable { case local, claude }

enum CardKind: String, Codable, Sendable {
    case list, search, read, write, rename, move, backup, error
    case hint, handover   // handover = ÜBERGABE-Knoten (lokal → Claude) in der Flugbahn
}

struct ActionCard: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let kind: CardKind
    let actor: Actor?
    let title: String
    let detail: String
    let durationMS: Int?
    let createdAt: Date
}

/// Gefundener Wert für das Fundstück-Panel („BISHER GEFUNDEN")
struct Finding: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let value: String
    let actor: Actor
    let createdAt: Date
}

struct ChatMessage: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let role: Role
    let text: String
    let cards: [ActionCard]
    let findings: [Finding]
    let createdAt: Date
    init(role: Role, text: String, cards: [ActionCard] = [], findings: [Finding] = []) {
        self.id = UUID(); self.role = role; self.text = text
        self.cards = cards; self.findings = findings; self.createdAt = Date()
    }
}
