import Foundation

/// Pure function: compares two catalogs against the user's subscriptions and
/// emits the `PriceChangeAlert` rows that should be persisted. The orchestrator
/// (`PresetSync`) is responsible for writing them through `AlertRepository`.
enum PriceChangeDiffer {

    static func diff(
        old: PresetCatalog,
        new: PresetCatalog,
        subscriptions: [Subscription],
        now: Date = .now
    ) -> [PriceChangeAlert] {
        let oldByID = Dictionary(uniqueKeysWithValues: old.items.map { ($0.id, $0) })

        var alerts: [PriceChangeAlert] = []
        for newItem in new.items {
            guard let oldItem = oldByID[newItem.id] else { continue }
            guard oldItem.defaultAmount != newItem.defaultAmount else { continue }

            for sub in subscriptions where sub.presetId == newItem.id {
                _ = sub // referenced for readability; the alert doesn't link back to the sub
                alerts.append(PriceChangeAlert(
                    presetId: newItem.id,
                    planKey: newItem.defaultPlanName,
                    oldAmount: oldItem.defaultAmount,
                    newAmount: newItem.defaultAmount,
                    currency: newItem.defaultCurrency,
                    effectiveDate: now,
                    messageEn: enMessage(item: newItem,
                                         oldAmount: oldItem.defaultAmount,
                                         newAmount: newItem.defaultAmount),
                    messageZh: zhMessage(item: newItem,
                                         oldAmount: oldItem.defaultAmount,
                                         newAmount: newItem.defaultAmount),
                    seenAt: nil,
                    createdAt: now
                ))
            }
        }
        return alerts
    }

    private static func enMessage(item: PresetItem,
                                  oldAmount: Decimal,
                                  newAmount: Decimal) -> String {
        let oldStr = AmountFormatter.format(oldAmount, currency: item.defaultCurrency)
        let newStr = AmountFormatter.format(newAmount, currency: item.defaultCurrency)
        let direction = newAmount > oldAmount ? "raised" : "lowered"
        return "\(item.name) \(direction) its \(item.defaultPlanName) price from \(oldStr) to \(newStr)."
    }

    private static func zhMessage(item: PresetItem,
                                  oldAmount: Decimal,
                                  newAmount: Decimal) -> String {
        let oldStr = AmountFormatter.format(oldAmount, currency: item.defaultCurrency)
        let newStr = AmountFormatter.format(newAmount, currency: item.defaultCurrency)
        let direction = newAmount > oldAmount ? "上调" : "下调"
        return "\(item.name) \(item.defaultPlanName) 价格已\(direction)，由 \(oldStr) 变为 \(newStr)。"
    }
}
