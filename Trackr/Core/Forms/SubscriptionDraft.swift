import Foundation

/// Editable form model behind the Add / Edit Subscription forms. Keeps everything
/// as plain Swift so the form's validation can be unit-tested without touching
/// SwiftUI or SwiftData.
struct SubscriptionDraft: Equatable {
    var name: String
    var planName: String = ""
    var amountString: String
    var currency: String
    var billingCycle: BillingCycle
    /// Used only when `billingCycle == .customDays(_)`. Stored separately so the
    /// picker can switch between cycles without losing the user's typed value.
    var customDays: Int
    var startDate: Date
    /// Optional override for the next billing date. Only set by import flows
    /// where we know an *absolute future renewal date* (e.g. the iOS
    /// Subscriptions screenshot says "12月26日续期"). When nil, the next
    /// billing falls back to `startDate` — the "fresh sub starting today"
    /// case used by the manual Add form.
    var nextBillingDate: Date?
    var category: Category
    var notes: String = ""
    var urlString: String = ""

    enum ValidationError: Error, Equatable {
        case emptyName
        case invalidAmount
        case invalidCustomDays
    }

    static func empty(defaultCurrency: String) -> SubscriptionDraft {
        SubscriptionDraft(
            name: "",
            amountString: "",
            currency: defaultCurrency,
            billingCycle: .monthly,
            customDays: 30,
            startDate: .now,
            category: .other
        )
    }

    /// Builds a real `Subscription`. Throws `ValidationError` if any rule fails.
    /// `nextBillingDate` defaults to `startDate` because the first billing is the
    /// start. M4's `RenewalCalculator` advances it whenever the user marks the
    /// cycle paid.
    func makeSubscription() throws -> Subscription {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ValidationError.emptyName }

        guard let amount = Decimal(string: amountString), amount > 0 else {
            throw ValidationError.invalidAmount
        }

        let resolvedCycle: BillingCycle
        if case .customDays = billingCycle {
            guard customDays > 0 else { throw ValidationError.invalidCustomDays }
            resolvedCycle = .customDays(customDays)
        } else {
            resolvedCycle = billingCycle
        }

        return Subscription(
            name: trimmedName,
            planName: planName.isEmpty ? nil : planName,
            amount: amount,
            currency: currency.uppercased(),
            billingCycle: resolvedCycle,
            nextBillingDate: nextBillingDate ?? startDate,
            startDate: startDate,
            category: category,
            notes: notes.isEmpty ? nil : notes,
            url: URL(string: urlString)
        )
    }
}
