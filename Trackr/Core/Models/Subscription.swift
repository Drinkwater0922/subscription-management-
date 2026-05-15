import Foundation
import SwiftData

/// A recurring subscription the user is tracking. Source of truth for everything
/// the app displays on the Home / Detail screens.
@Model
final class Subscription {
    // Identity
    @Attribute(.unique) var id: UUID

    // Core fields
    var name: String
    var planName: String?
    var amount: Decimal
    var currency: String          // ISO 4217 — "USD", "CNY", etc.
    var billingCycle: BillingCycle
    var nextBillingDate: Date
    var startDate: Date           // anchor for cycle math — never changes after creation
    var category: Category

    // Optional metadata
    var paymentMethod: String?
    var notes: String?
    var url: URL?
    /// Either `"preset:<id>"` for library-backed subs, or `"custom:emoji:<emoji>"` for manual ones.
    var iconRef: String
    /// Set when this Subscription was added from the AI preset library. Used by M5 price-change matching.
    var presetId: String?

    // State
    var isActive: Bool
    var pausedUntil: Date?

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        planName: String? = nil,
        amount: Decimal,
        currency: String,
        billingCycle: BillingCycle,
        nextBillingDate: Date,
        startDate: Date,
        category: Category,
        paymentMethod: String? = nil,
        notes: String? = nil,
        url: URL? = nil,
        iconRef: String = "custom:emoji:❓",
        presetId: String? = nil,
        isActive: Bool = true,
        pausedUntil: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.planName = planName
        self.amount = amount
        self.currency = currency
        self.billingCycle = billingCycle
        self.nextBillingDate = nextBillingDate
        self.startDate = startDate
        self.category = category
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.url = url
        self.iconRef = iconRef
        self.presetId = presetId
        self.isActive = isActive
        self.pausedUntil = pausedUntil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
