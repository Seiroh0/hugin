import Foundation

struct Grant: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let url: URL
}
