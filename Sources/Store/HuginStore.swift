import Foundation
import SwiftData

@Model
final class StoredOrder {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var lastActor: String
    var payload: Data

    init(id: UUID, title: String, createdAt: Date, lastActor: String, payload: Data) {
        self.id = id; self.title = title; self.createdAt = createdAt
        self.lastActor = lastActor; self.payload = payload
    }
}

struct OrderSummary: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let createdAt: Date
    let actor: String
}

final class HuginStore: @unchecked Sendable {
    private let container: ModelContainer

    init(inMemory: Bool = false) throws {
        let cfg = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: StoredOrder.self, configurations: cfg)
    }

    func save(orderID: UUID, title: String, actor: String, messages: [ChatMessage]) throws {
        let ctx = ModelContext(container)
        let payload = try JSONEncoder().encode(messages)
        let existing = (try? ctx.fetch(FetchDescriptor<StoredOrder>()))?.first { $0.id == orderID }
        if let existing {
            existing.title = title; existing.lastActor = actor; existing.payload = payload
        } else {
            ctx.insert(StoredOrder(id: orderID, title: title, createdAt: Date(),
                                   lastActor: actor, payload: payload))
        }
        try ctx.save()
    }

    func load(orderID: UUID) -> [ChatMessage] {
        let ctx = ModelContext(container)
        let existing = (try? ctx.fetch(FetchDescriptor<StoredOrder>()))?.first { $0.id == orderID }
        guard let payload = existing?.payload else { return [] }
        return (try? JSONDecoder().decode([ChatMessage].self, from: payload)) ?? []
    }

    func listOrders() -> [OrderSummary] {
        let ctx = ModelContext(container)
        let all = (try? ctx.fetch(FetchDescriptor<StoredOrder>())) ?? []
        return all
            .map { OrderSummary(id: $0.id, title: $0.title, createdAt: $0.createdAt, actor: $0.lastActor) }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
