import SwiftUI

/// List of pump events with swipe-to-delete.
struct PumpHistoryView: View {
    let pumpEvents: [PumpEvent]
    let onDelete: (PumpEvent) -> Void

    var body: some View {
        if pumpEvents.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "drop.triangle")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text("No pump events yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            VStack(spacing: 0) {
                ForEach(pumpEvents.reversed()) { event in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.date, format: .dateTime.month(.abbreviated).day().year())
                                .font(.subheadline)
                            Text("\(Int(event.gallonsAtPump)) gal at pump")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            onDelete(event)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                }
            }
        }
    }
}
