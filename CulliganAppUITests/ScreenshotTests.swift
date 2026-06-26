import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-hasShownNotificationPrompt", "YES"]
        setupSnapshot(app)
    }

    func testCaptureScreenshots() throws {
        // --- Onboarding screenshots ---
        app.launchArguments += ["-hasCompletedOnboarding", "NO"]
        app.launch()

        // 1. Onboarding — first page
        snapshot("01-Onboarding")

        // Tap Next to second page
        let nextButton = app.buttons["Next"]
        if nextButton.waitForExistence(timeout: 3) {
            nextButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        snapshot("02-OnboardingInsights")

        // Tap Next to third page
        if nextButton.waitForExistence(timeout: 3) {
            nextButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        snapshot("03-OnboardingTank")

        // --- App screenshots: relaunch with onboarding completed ---
        app.launchArguments = app.launchArguments.filter { $0 != "-hasCompletedOnboarding" && $0 != "NO" }
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launch()

        // 4. Login screen
        let emailField = app.textFields["Email"]
        _ = emailField.waitForExistence(timeout: 5)
        snapshot("04-Login")

        // Enter credentials and sign in
        if emailField.exists {
            emailField.tap()
            emailField.typeText("washingtondavid@hotmail.com")

            let passwordField = app.secureTextFields["Password"]
            if passwordField.waitForExistence(timeout: 3) {
                passwordField.tap()
                passwordField.typeText("*TAXman0725")
            }

            app.buttons["Sign In"].tap()
        }

        // Wait for dashboard to load
        let dashboardTitle = app.staticTexts["gal today"]
        _ = dashboardTitle.waitForExistence(timeout: 15)
        Thread.sleep(forTimeInterval: 2)

        // Enable tank tracking in Settings so Tank tab appears
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()
            Thread.sleep(forTimeInterval: 1)

            let tankToggle = app.switches["Track Holding Tank"]
            if tankToggle.waitForExistence(timeout: 3) {
                if tankToggle.value as? String == "0" {
                    tankToggle.tap()
                    Thread.sleep(forTimeInterval: 1)
                }
            }
        }

        // 5. Dashboard
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        if dashboardTab.waitForExistence(timeout: 3) {
            dashboardTab.tap()
            Thread.sleep(forTimeInterval: 2)
        }
        snapshot("05-Dashboard")

        // 6. Usage tab
        let usageTab = app.tabBars.buttons["Usage"]
        if usageTab.waitForExistence(timeout: 5) {
            usageTab.tap()
            Thread.sleep(forTimeInterval: 2)
            snapshot("06-Usage")
        }

        // 7. Tank tab — try by label, then by tab bar button index (3rd of 4)
        let tankTab = app.tabBars.buttons["Tank"]
        if tankTab.waitForExistence(timeout: 5) {
            tankTab.tap()
            Thread.sleep(forTimeInterval: 2)
            snapshot("07-Tank")
        } else if app.tabBars.buttons.count >= 4 {
            app.tabBars.buttons.element(boundBy: 2).tap()
            Thread.sleep(forTimeInterval: 2)
            snapshot("07-Tank")
        }

        // 8. Settings tab
        if settingsTab.exists {
            settingsTab.tap()
            Thread.sleep(forTimeInterval: 1)
            snapshot("08-Settings")
        }
    }
}
