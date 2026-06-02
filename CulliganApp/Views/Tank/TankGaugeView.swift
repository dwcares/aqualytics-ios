import SwiftUI

/// Animated circular gauge showing tank fill level.
struct TankGaugeView: View {
    let fillPercentage: Double
    let gallonsUsed: Double
    let capacity: Double

    @State private var animatedFill: Double = 0

    private var fillColor: Color {
        if fillPercentage >= 75 { return .red }
        if fillPercentage >= 50 { return .orange }
        return .cyan
    }

    private var trackColor: Color {
        Color(.systemGray5)
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))

            // Fill arc
            Circle()
                .trim(from: 0, to: animatedFill / 100)
                .stroke(
                    fillColor.gradient,
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center text
            VStack(spacing: 4) {
                Text("\(Int(fillPercentage))%")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text("\(Int(gallonsUsed)) of \(Int(capacity)) gal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 180, height: 180)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedFill = fillPercentage
            }
        }
        .onChange(of: fillPercentage) { _, newValue in
            withAnimation(.easeOut(duration: 0.4)) {
                animatedFill = newValue
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        TankGaugeView(fillPercentage: 35, gallonsUsed: 700, capacity: 2000)
        TankGaugeView(fillPercentage: 65, gallonsUsed: 1300, capacity: 2000)
        TankGaugeView(fillPercentage: 85, gallonsUsed: 1700, capacity: 2000)
    }
}
