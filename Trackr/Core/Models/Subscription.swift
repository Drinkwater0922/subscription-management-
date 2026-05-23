import Foundation
import SwiftData

/// A recurring subscription the user is tracking. Source of truth for everything
/// the app displays on the Home / Detail screens.
@Model
final class Subscription {
    // Identity
    var id: UUID

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

    // FX (M11) — pinned at creation when `currency != homeCurrency`. All three
    // fields are nilable + additive so old records (and CloudKit) keep working.
    /// FX rate at pin time. To convert `amount` into the home currency:
    /// `amount * exchangeRateToHome`. nil means no rate was pinned.
    var exchangeRateToHome: Decimal?
    /// Date used when looking up the rate. Stored so the Detail screen can
    /// surface "@ 2026-05-16" alongside the converted amount.
    var exchangeRateAsOf: Date?
    /// What the user's home currency was at pin time. We snapshot it so that
    /// later changing `UserSettings.defaultCurrency` doesn't silently
    /// invalidate every pinned rate in the store.
    var homeCurrencyAtCreation: String?

    // Price history (v1.1) — per-subscription timeline of amount/currency
    // snapshots. Populated by `SubscriptionRepository.insert` (`.initial`
    // baseline) and the edit-save path (`.userEdit`). Cascade-delete so a
    // removed sub takes its history with it. Default empty so existing call
    // sites and TestFlight records continue to work without migration.
    @Relationship(deleteRule: .cascade, inverse: \PriceHistoryEntry.subscription)
    var priceHistory: [PriceHistoryEntry] = []

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
        exchangeRateToHome: Decimal? = nil,
        exchangeRateAsOf: Date? = nil,
        homeCurrencyAtCreation: String? = nil,
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
        self.exchangeRateToHome = exchangeRateToHome
        self.exchangeRateAsOf = exchangeRateAsOf
        self.homeCurrencyAtCreation = homeCurrencyAtCreation
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
