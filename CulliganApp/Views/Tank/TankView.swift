import SwiftUI

struct TankView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Tank Tracking",
                systemImage: "cylinder.fill",
                description: Text("Coming in Phase 5")
            )
            .navigationTitle("Tank")
        }
    }
}

#Preview {
    TankView()
}
