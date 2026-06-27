import SwiftUI

/// 3-screen onboarding walkthrough shown on first launch.
struct OnboardingView: View {
    let onComplete: () -> Void

    private let pageCount = 3
    @State private var currentPage = 0

    private var isLastPage: Bool { currentPage == pageCount - 1 }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                OnboardingPage(
                    icon: "drop.fill",
                    iconColor: .cyan,
                    title: "Your Water Data, Unlocked",
                    subtitle: "See how much water your household uses every day — with history that goes back months, not just 30 days."
                )
                .tag(0)

                OnboardingPage(
                    icon: "chart.bar.fill",
                    iconColor: .cyan,
                    title: "Insights at a Glance",
                    subtitle: "A visual calendar shows your usage patterns over time. Spot trends, catch spikes, and export your data anytime."
                )
                .tag(1)

                OnboardingPage(
                    icon: "cylinder.fill",
                    iconColor: .orange,
                    title: "Track Your Tank",
                    subtitle: "Optionally monitor your septic or holding tank. Know when it's time to pump — before it's an emergency."
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom page indicator — always visible so users can see how many
            // pages there are (the built-in dots only show while scrubbing).
            PageIndicator(count: pageCount, current: currentPage)
                .padding(.bottom, 16)

            // Bottom button
            Button {
                if isLastPage {
                    onComplete()
                } else {
                    withAnimation {
                        currentPage += 1
                    }
                }
            } label: {
                Text(isLastPage ? "Get Started" : "Next")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // Always kept in the layout so the button above doesn't shift
            // position on the final page; just hidden when there's nothing to skip.
            Button("Skip") {
                onComplete()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom, 24)
            .opacity(isLastPage ? 0 : 1)
            .disabled(isLastPage)
            .accessibilityHidden(isLastPage)
        }
    }
}

/// Always-visible row of dots showing the current page and total count.
private struct PageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.cyan : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: current)
        .accessibilityElement()
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

struct OnboardingPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
