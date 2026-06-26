# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS app for monitoring Culligan water softener devices. Built with SwiftUI, SwiftData, and Swift 6 strict concurrency. Includes a widget extension. Uses XcodeGen (`project.yml`) to generate the Xcode project.

## Build & Development Commands

```bash
# Generate Xcode project (after modifying project.yml or adding files)
xcodegen generate

# Build
xcodebuild -project CulliganApp.xcodeproj -scheme CulliganApp -sdk iphonesimulator build

# Run unit tests
xcodebuild -project CulliganApp.xcodeproj -scheme CulliganAppTests -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test

# Run UI tests
xcodebuild -project CulliganApp.xcodeproj -scheme CulliganAppUITests -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test

# Capture screenshots via fastlane
bundle exec fastlane screenshots
```

## Architecture

- **Target: iOS 17+, Swift 6** with `SWIFT_STRICT_CONCURRENCY: complete`
- **XcodeGen**: `project.yml` defines all targets — run `xcodegen generate` after structural changes
- **Targets**: `CulliganApp` (main), `CulliganWidgetExtension` (widgets), `CulliganAppTests`, `CulliganAppUITests`

### App Structure (`CulliganApp/`)

- **CulliganAPI/**: `CulliganClient` (actor-based API client for Culligan IoT API), `KeychainService`, and API models (`AuthModels`, `DeviceModels`, `CommandModels`)
- **Data/**: SwiftData models (`UserSettings`, `PumpEvent`, `DailyUsageRecord`) and `SharedConfig` (shared `ModelContainer` setup for app + widget via App Groups)
- **ViewModels/**: `@Observable` view models — `AuthViewModel`, `DashboardViewModel`, `TankViewModel`, `UsageViewModel`
- **Views/**: SwiftUI views organized by feature (Dashboard, Usage, Tank, Auth, Settings, Components)
- **Services/**: `BackgroundRefreshService`, `NotificationService`, `UsageSyncService`, `ExportService`

### Widget Extension (`CulliganWidgetExtension/`)

Shares `Data/` models and `AuthModels` with the main app via App Groups (`group.com.dwcares.culligan`).

### App Flow

`RootView` controls navigation: Onboarding → Login → TabView (Dashboard, Usage, Tank [optional], Settings). Auth state managed by `AuthViewModel` using `@Observable`.

## Key Patterns

- **Concurrency**: `CulliganClient` is an `actor`; all API calls are async/await. Swift 6 strict concurrency is enforced.
- **Data sharing**: Main app and widget share data via App Groups and a shared `ModelContainer` from `SharedConfig`.
- **Auth**: Token-based auth with Keychain storage; `CulliganClient` handles token lifecycle and refresh.
