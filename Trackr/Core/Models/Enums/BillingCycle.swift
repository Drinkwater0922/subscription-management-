import Foundation

/// How often a subscription bills. `customDays` covers irregular cycles like
/// "every 60 days" for non-standard plans.
enum BillingCycle: Codable, Equatable, Hashable {
    case weekly
    case monthly
    case yearly
    case customDays(Int)
}
