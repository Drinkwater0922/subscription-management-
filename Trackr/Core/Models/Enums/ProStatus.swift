import Foundation

/// User's current Pro entitlement state, derived from StoreKit transactions in M6.
enum ProStatus: String, Codable, CaseIterable, Hashable {
    case free
    case proLifetime
}
