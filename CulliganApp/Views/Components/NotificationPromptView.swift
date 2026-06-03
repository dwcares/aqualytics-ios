import SwiftUI

/// Soft prompt shown before the system notification permission dialog.
/// Explains the value of notifications so users understand before deciding.
struct NotificationPromptView: View {
    let onEnable: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(.cyan)

            // Title
            Text("Stay in the Loop")
                .font(.title2.bold())

            // Value summary
            VStack(alignment: .leading, spacing: 16) {
                NotificationBenefit(
                    icon: "drop.triangle.fill",
                    color: .red,
                    title: "Leak Detection",
                    description: "Get alerted when usage spikes above normal — catch leaks early."
                )
                NotificationBenefit(
                    icon: "cylinder.fill",
                    color: .orange,
                    title: "Tank Alerts",
                    description: "Know when your holding tank is getting full before it's too late."
                )
                NotificationBenefit(
                    icon: "cube.fill",
                    color: .cyan,
                    title: "Salt Reminders",
                    description: "A heads up when your softener is running low on salt."
                )
            }
            .padding()
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16))

            Spacer()

            // Actions
            VStack(spacing: 12) {
                Button {
                    onEnable()
                } label: {
                    Text("Enable Notifications")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)

                Button {
                    onSkip()
                } label: {
                    Text("Maybe Later")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
    }
}

struct NotificationBenefit: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NotificationPromptView(onEnable: {}, onSkip: {})
}
