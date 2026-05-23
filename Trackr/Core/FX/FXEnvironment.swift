import SwiftUI

/// SwiftUI environment key for the FX rate lookup client. Production code
/// installs `FrankfurterFXClient`; tests swap in `FakeFXClient`.
private struct FXRateClientKey: EnvironmentKey {
    static let defaultValue: FXRateClient? = nil
}

extension EnvironmentValues {
    var fxRateClient: FXRateClient? {
        get { self[FXRateClientKey.self] }
        set { self[FXRateClientKey.self] = newValue }
    }
}

/// SwiftUI environment key for the v1.1 whole-table FX rates client. Used by
/// `HomeView` to drive the foreground/Home-appear refresh of `FXRateTable`.
private struct FXLatestRatesClientKey: EnvironmentKey {
    static let defaultValue: (any FXLatestRatesClient)? = nil
}

extension EnvironmentValues {
    var fxLatestRatesClient: (any FXLatestRatesClient)? {
        get { self[FXLatestRatesClientKey.self] }
        set { self[FXLatestRatesClientKey.self] = newValue }
    }
}
