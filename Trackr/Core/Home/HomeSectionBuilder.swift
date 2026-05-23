import Foundation

/// Pure builder for the v1.1 Home list — produces ordered sections so the
/// Home view never has to do its own filter/sort dance. Section semantics
/// come from the v1.1 closed-loop spec:
///
///   * **FREE TRIALS** first. Items where the sub is active and
///     `isTrial(at: now)` (i.e. `trialEndsAt > now`). Sorted by
///     `trialEndsAt` ascending so the trial converting soonest sits at the
///     top — those are the highest-cancel-anxiety rows.
///   * **ACTIVE** below. Everything else, sorted by `nextBillingDate`
///     ascending so the next charge surfaces first.
///
/// Empty sections are omitted from the result.
enum HomeSectionBuilder {

    enum Kind: Equatable {
        case freeTrials
        case active
    }

    struct Section: Equatable {
        let kind: Kind
        let items: [Subscription]
    }

    static func build(from subscriptions: [Subscription],
                      now: Date = .now) -> [Section] {
        var trials: [Subscription] = []
        var active: [Subscription] = []

        for sub in subscriptions {
            if sub.isActive && sub.isTrial(at: now) {
                trials.append(sub)
            } else {
                active.append(sub)
            }
        }

        // Order within each section. We do this here, not via SwiftData
        // sort, so the same builder can serve filtered subarrays and
        // tests without a model context.
        trials.sort {
            ($0.trialEndsAt ?? .distantFuture) < ($1.trialEndsAt ?? .distantFuture)
        }
        active.sort { $0.nextBillingDate < $1.nextBillingDate }

        var sections: [Section] = []
        if !trials.isEmpty { sections.append(Section(kind: .freeTrials, items: trials)) }
        if !active.isEmpty { sections.append(Section(kind: .active, items: active)) }
        return sections
    }

    /// Localized uppercase section title in the pixel-art system.
    static func title(for kind: Kind, locale: Locale = .current) -> String {
        let isChinese = locale.language.languageCode?.identifier == "zh"
        switch kind {
        case .freeTrials:
            return isChinese ? "免费试用" : "FREE TRIALS"
        case .active:
            return isChinese ? "进行中" : "ACTIVE"
        }
    }
}
