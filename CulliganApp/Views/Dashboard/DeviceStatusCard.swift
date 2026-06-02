import SwiftUI

struct DeviceStatusCard: View {
    let device: SoftenerDevice

    var body: some View {
        HStack(spacing: 12) {
            // Status dot
            Circle()
                .fill(device.isOnline ? .green : .red)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .fill(device.isOnline ? .green.opacity(0.3) : .red.opacity(0.3))
                        .frame(width: 20, height: 20)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.headline)
                Text(device.isOnline ? "Online" : "Offline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let model = device.model {
                Text(model)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
