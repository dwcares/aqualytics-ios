import Foundation
import Observation

@Observable
@MainActor
final class AuthViewModel {
    var isAuthenticated = false
    var isLoading = false
    var errorMessage: String?

    /// True until the initial auth restoration finishes, so the UI can show a
    /// splash instead of briefly flashing the login screen on launch.
    var isInitializing = true

    /// Whether stored credentials exist. Lets the launch UI show the dashboard
    /// skeleton for a likely-signed-in user, vs. login when there's nothing to restore.
    let hasStoredCredentials = KeychainService.loadCredentials() != nil

    let client = CulliganClient()

    /// Check if we have existing valid auth from keychain
    func checkExistingAuth() async {
        defer { isInitializing = false }
        if await client.isAuthenticated {
            isAuthenticated = true
        } else if KeychainService.loadCredentials() != nil {
            // Try to refresh using stored credentials
            do {
                try await client.refreshAccessToken()
                isAuthenticated = true
            } catch {
                // Refresh failed — try re-login with stored creds
                await reloginWithStoredCredentials()
            }
        }
    }

    /// Login with email and password
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await client.login(email: email, password: password)
            isAuthenticated = true
        } catch let error as CulliganError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Logout
    func logout() async {
        await client.logout()
        isAuthenticated = false
    }

    /// Try to re-login using stored keychain credentials
    private func reloginWithStoredCredentials() async {
        guard let creds = KeychainService.loadCredentials() else { return }
        do {
            try await client.login(email: creds.email, password: creds.password)
            isAuthenticated = true
        } catch {
            // Stored credentials invalid — user needs to log in again
            isAuthenticated = false
        }
    }
}
