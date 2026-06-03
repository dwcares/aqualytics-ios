import SwiftUI

/// 3-screen onboarding walkthrough shown on first launch.
struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0

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
            .tabViewStyle(.page(indexDisplayMode: .always))

            // Bottom button
            Button {
                if currentPage < 2 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    onComplete()
                }
            } label: {
                Text(currentPage < 2 ? "Next" : "Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            if currentPage < 2 {
                Button("Skip") {
                    onComplete()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
            } else {
                Color.clear.frame(height: 44)
            }
        }
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
