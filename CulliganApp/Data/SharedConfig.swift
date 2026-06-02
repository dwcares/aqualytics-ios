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
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

        return container.appendingPathComponent("CulliganApp.store")
    }
}
