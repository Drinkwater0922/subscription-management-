import Foundation

/// Lifecycle of a single `RenewalEvent` — i.e. one billing occurrence.
enum RenewalStatus: String, Codable, CaseIterable, Hashable {
    case scheduled
    case paid
    case skipped
}
