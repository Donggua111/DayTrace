import Foundation

struct DomainInterval: Identifiable {
    let id = UUID()
    let domain: String
    let start: Date
    let end: Date
    let duration: TimeInterval
}
