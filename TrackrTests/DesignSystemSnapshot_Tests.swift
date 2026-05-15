import XCTest
import SwiftUI
import SnapshotTesting
@testable import Trackr

final class DesignSystemSnapshotTests: XCTestCase {

    /// Set to `true` to (re-)generate baseline snapshots. Commit and set back to `false`.
    private let record: Bool = false

    override func setUp() {
        super.setUp()
        isRecording = record
    }

    func test_homeView_iPhone15() {
        let view = HomeView()
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
            MonoSquareIcon(name: "AI Chat Pro")
            MonoSquareIcon(name: "Code Editor +")
            MonoSquareIcon(name: "")
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
            TrackrColors.bg.frame(width: 200, height: 200)
            FloatingActionButton(action: { }).padding(20)
        }
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }
}
