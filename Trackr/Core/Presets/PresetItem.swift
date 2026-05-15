import Foundation

/// One entry in the preset library. Mirrors the JSON schema of
/// `presets.bundled.json` / the remote catalog. `defaultAmount` is decoded
/// from a String to preserve `Decimal` precision (JSON numbers round-trip
/// through `Double` otherwise).
struct PresetItem: Codable, Equatable, Hashable {
    let id: String
    let name: String
    let defaultPlanName: String
    let defaultAmount: Decimal
    let defaultCurrency: String
    let defaultCycle: BillingCycle
    let category: Category
    let iconRef: String

    enum CodingKeys: String, CodingKey {
        case id, name, defaultPlanName, defaultAmount, defaultCurrency,
             defaultCycle, category, iconRef
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.defaultPlanName = try c.decode(String.self, forKey: .defaultPlanName)

        let amountString = try c.decode(String.self, forKey: .defaultAmount)
        guard let amount = Decimal(string: amountString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .defaultAmount, in: c,
                debugDescription: "Expected Decimal-parsable string, got \(amountString)"
            )
        }
        self.defaultAmount = amount

        self.defaultCurrency = try c.decode(String.self, forKey: .defaultCurrency)

        let cycleString = try c.decode(String.self, forKey: .defaultCycle)
        switch cycleString {
        case "monthly": self.defaultCycle = .monthly
        case "yearly":  self.defaultCycle = .yearly
        case "weekly":  self.defaultCycle = .weekly
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .defaultCycle, in: c,
                debugDescription: "Unknown cycle \(cycleString) — M5 doesn't ship customDays presets"
            )
        }

        let categoryString = try c.decode(String.self, forKey: .category)
        guard let cat = Category(rawValue: categoryString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .category, in: c,
                debugDescription: "Unknown category \(categoryString)"
            )
        }
        self.category = cat

        self.iconRef = try c.decode(String.self, forKey: .iconRef)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(defaultPlanName, forKey: .defaultPlanName)
        try c.encode("\(defaultAmount)", forKey: .defaultAmount)
        try c.encode(defaultCurrency, forKey: .defaultCurrency)
        let cycleString: String
        switch defaultCycle {
        case .monthly:           cycleString = "monthly"
        case .yearly:            cycleString = "yearly"
        case .weekly:            cycleString = "weekly"
        case .customDays:        cycleString = "monthly" // not exported in M5
        }
        try c.encode(cycleString, forKey: .defaultCycle)
        try c.encode(category.rawValue, forKey: .category)
        try c.encode(iconRef, forKey: .iconRef)
    }

    /// Convert the preset into a `SubscriptionDraft` so the Add form can render
    /// the user's tweaks before they hit SAVE.
    func toDraft(defaultStart: Date = .now) -> SubscriptionDraft {
        SubscriptionDraft(
            name: name,
            planName: defaultPlanName,
            amountString: "\(defaultAmount)",
            currency: defaultCurrency,
            billingCycle: defaultCycle,
            customDays: 30,
            startDate: defaultStart,
            category: category,
            notes: "",
            urlString: ""
        )
    }
}
