import SwiftUI

struct UsageView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Usage History",
                systemImage: "chart.bar.fill",
                description: Text("Coming in Phase 3")
            )
            .navigationTitle("Usage")
        }
    }
}

#Preview {
    UsageView()
}
