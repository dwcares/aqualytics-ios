import Foundation
import SwiftData

/// Shared constants and SwiftData configuration for main app + widget.
enum SharedConfig {
    static let appGroupID = "group.com.dwcares.culligan"

    /// SwiftData container shared between main app and widget extension.
    static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            DailyUsageRecord.self,
            PumpEvent.self,
            UserSettings.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// URL for the shared SwiftData store in the App Group container.
    static var storeURL: URL {
        // App Group container (works when properly provisioned)
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            return container.appendingPathComponent("CulliganApp.store")
        }

        // Fallback for simulator / no provisioning — use default location
        // Note: widgets won't be able to read this; requires App Group provisioning
        return URL.applicationSupportDirectory.appendingPathComponent("CulliganApp.store")
    }
}
