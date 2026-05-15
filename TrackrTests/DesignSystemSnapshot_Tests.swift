import XCTest
import SwiftUI
import SwiftData
import SnapshotTesting
@testable import Trackr

final class DesignSystemSnapshotTests: XCTestCase {

    /// Set to `true` to (re-)generate baseline snapshots. Commit and set back to `false`.
    ///
    /// Baselines were recorded on the **iPhone 16 simulator running iOS 18.1**. If you
    /// see snapshot diffs on a different simulator/OS, re-record on the same target
    /// rather than treating the diff as a regression.
    private let record: Bool = false

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    override func invokeTest() {
        withSnapshotTesting(record: record ? .all : .missing) {
            super.invokeTest()
        }
    }

    @MainActor
    func test_homeView_iPhone15() {
        let entitlement = ProEntitlement(client: FakeStoreKitClient(), container: container)
        let view = HomeView()
            .modelContainer(container)
            .environment(AppDeepLinkRouter())
            .environment(entitlement)
            .environment(PaywallTriggerCoordinator())
            .frame(width: 393, height: 852)    // iPhone 15 logical points
            .background(TrackrColors.bg)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 393, height: 852)))
    }

    func test_pixelText_renders() {
        let view = PixelText("MONTHLY · USD",
                             size: TrackrTypography.Scale.sectionLabel,
                             color: TrackrColors.fg2,
                             tracking: 2)
            .padding()
            .background(TrackrColors.bg)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    func test_monoSquareIcon_variants() {
        let view = HStack(spacing: 12) {
            MonoSquareIcon(name: "AI Chat Pro")     // multi-word -> "AC"
            MonoSquareIcon(name: "Code Editor +")   // punctuation stripped -> "CE"
            MonoSquareIcon(name: "Copilot")         // single word, 2+ letters -> "CO"
            MonoSquareIcon(name: "X")               // single letter -> "X"
            MonoSquareIcon(name: "")                // empty -> "?"
        }
        .padding()
        .background(TrackrColors.bg)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    func test_dashedDivider() {
        let view = DashedDivider()
            .frame(width: 320)
            .padding()
            .background(TrackrColors.bg)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    func test_trackrButton_bothVariants() {
        let view = VStack(spacing: 12) {
            TrackrButton("CONTINUE") { }
            TrackrButton("RESTORE", variant: .outlined) { }
        }
        .frame(width: 320)
        .padding()
        .background(TrackrColors.bg)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    func test_fab() {
        let view = ZStack(alignment: .bottomTrailing) {
            TrackrColors.bg.frame(width: 220, height: 220)
            FloatingActionButton(action: { }).padding(20)
        }
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }
}
