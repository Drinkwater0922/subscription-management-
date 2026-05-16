import Foundation

/// Deep-link target for iOS's built-in subscription management page. Bouncing
/// users through this URL is the closest thing we have to "import existing
/// Apple subscriptions" — the user takes a screenshot of what they see, then
/// returns and feeds the screenshot into the IMPORT FROM PHOTO flow.
///
/// Documented here:
/// https://developer.apple.com/documentation/storekit/in_app_purchase/original_api_for_in-app_purchase/testing_in-app_purchases_with_sandbox/testing_subscription_renewals_and_management
/// (The `itms-apps://apps.apple.com/account/subscriptions` URL is the public
/// equivalent of "Settings → Apple ID → Subscriptions".)
enum AppleSubscriptionsRoute {

    /// Deep-link string that opens the iOS Subscriptions page. Kept as a
    /// `String` constant so it's easy to assert in tests.
    static let deepLinkString = "itms-apps://apps.apple.com/account/subscriptions"

    static var deepLinkURL: URL { URL(string: deepLinkString)! }
}
