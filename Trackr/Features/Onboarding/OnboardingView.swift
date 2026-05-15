import SwiftUI
import UserNotifications

/// 3-page onboarding shown on cold launch. `onComplete` fires when the user
/// finishes the permission page (regardless of grant/deny). The host
/// (`TrackrApp`) is responsible for writing `UserSettings.onboardingCompletedAt`.
struct OnboardingView: View {

    let onComplete: () -> Void

    @State private var selectedPage = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedPage) {
                OnboardingBrandPage().tag(0)
                OnboardingValuePage().tag(1)
                OnboardingPermissionPage(
                    onEnable: enableThenComplete,
                    onSkip: onComplete
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            footer
        }
        .background(TrackrColors.bg.ignoresSafeArea())
    }

    private var footer: some View {
        VStack(spacing: 16) {
            pageDots
            if selectedPage < 2 {
                TrackrButton(selectedPage == 0 ? "GET STARTED" : "CONTINUE") {
                    withAnimation { selectedPage += 1 }
                }
                .padding(.horizontal, 32)
            }
        }
        .padding(.bottom, 32)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { idx in
                Rectangle()
                    .fill(idx == selectedPage ? TrackrColors.accent : TrackrColors.fg3)
                    .frame(width: 16, height: 4)
            }
        }
    }

    private func enableThenComplete() {
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            onComplete()
        }
    }
}

#Preview { OnboardingView(onComplete: {}).preferredColorScheme(.dark) }
