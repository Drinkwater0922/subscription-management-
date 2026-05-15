import Foundation

/// Trackr's view of the iCloud account state. Mirrors a subset of
/// `CKAccountStatus` so the decider stays free of `CloudKit` imports.
enum ICloudAccountStatus {
    case available
    case noAccount
    case restricted
    case couldNotDetermine
}

/// Which SwiftData storage mode to use this launch.
enum SyncMode: Equatable {
    case localOnly
    case cloudKit
}

/// Pure decision rule: CloudKit only when the user is Pro AND iCloud is
/// available. Everything else is local-only.
enum SyncDecider {
    static func decide(proStatus: ProStatus, iCloud: ICloudAccountStatus) -> SyncMode {
        guard FeatureGate.isAllowed(.iCloudSync, given: proStatus) else { return .localOnly }
        return iCloud == .available ? .cloudKit : .localOnly
    }
}
