import Foundation

/// Formats a `Decimal` amount and ISO 4217 currency code into a display string.
/// Always emits two fractional digits per the spec ("$20.00", not "$20").
enum AmountFormatter {

    /// Format `amount` as `currency`. The result respects the currency's conventional
    /// symbol and grouping (USD = $1,775.00; CNY = ¥21.00) regardless of the user's
    /// system locale — we want consistent app-wide display until M8 i18n lands.
    static func format(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        // en_US_POSIX keeps grouping & decimal separators stable across user locales.
        // M8 i18n revisits and routes through user.language setting.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currency) \(amount)"
    }
}
