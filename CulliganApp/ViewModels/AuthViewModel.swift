import Foundation
import Observation

@Observable
@MainActor
final class AuthViewModel {
    var isAuthenticated = false
    var isLoading = false
    var errorMessage: String?

    let client = CulliganClient()

    /// Check if we have existing valid auth from keychain
    func checkExistingAuth() async {
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
