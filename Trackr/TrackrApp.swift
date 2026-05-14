import SwiftUI

@main
struct TrackrApp: App {
    var body: some Scene {
        WindowGroup {
            // Placeholder. Real HomeView lands in Task 11.
            Text("TRACKR")
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
                .preferredColorScheme(.dark)
        }
    }
}
