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
