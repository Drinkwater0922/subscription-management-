import Foundation

/// Formats a `Decimal` amount and ISO 4217 currency code into a display string.
/// Always emits two fractional digits per the spec ("$20.00", not "$20").
///
/// Implementation note: we deliberately avoid `NumberFormatter.numberStyle = .currency`
/// because its symbol selection is locale-coupled — e.g. CNY in English locales becomes
/// "CN¥21.00" rather than "¥21.00", and en_US_POSIX inserts a no-break space between
/// the symbol and digits. We control the symbol explicitly via `currencySymbol(for:)`
/// and use `NumberFormatter.numberStyle = .decimal` for thousands grouping + fraction
/// digits only.
enum AmountFormatter {

    /// Format `amount` as `currency`. Output shape is `<symbol><digits>` for known
    /// codes (e.g. `$1,775.00`, `¥21.00`) and `<code> <digits>` for unknown codes
    /// (e.g. `ZZZ 10.00`).
    static func format(_ amount: Decimal, currency: String) -> String {
        let symbol = currencySymbol(for: currency)
        let digits = decimalFormatter.string(from: NSDecimalNumber(decimal: amount))
            ?? "\(amount)"
        return symbol + digits
    }

    private static let decimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        f.decimalSeparator = "."
        f.usesGroupingSeparator = true
        f.groupingSize = 3
        return f
    }()

    /// Returns the prefix to use for a given ISO 4217 code. Known codes return their
    /// canonical symbol with no trailing space. Unknown codes return `"<CODE> "`
    /// (with a trailing space) so the output still parses naturally.
    private static func currencySymbol(for code: String) -> String {
        switch code.uppercased() {
        case "USD": return "$"
        case "CNY": return "¥"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "HKD": return "HK$"
        case "SGD": return "S$"
        case "TWD": return "NT$"
        case "KRW": return "₩"
        case "INR": return "₹"
        case "AUD": return "A$"
        case "CAD": return "C$"
        default:    return code.uppercased() + " "
        }
    }
}
