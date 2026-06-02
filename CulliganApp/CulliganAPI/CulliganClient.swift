import Foundation

// MARK: - Culligan API Errors

enum CulliganError: LocalizedError {
    case authFailed(String)
    case notAuthenticated
    case tokenExpired
    case apiError(statusCode: Int, message: String)
    case networkError(Error)
    case timeout
    case decodingError(Error)
    case noSoftenerFound

    var errorDescription: String? {
        switch self {
        case .authFailed(let message):
            return message
        case .notAuthenticated:
            return "Not authenticated. Please sign in."
        case .tokenExpired:
            return "Session expired. Please sign in again."
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out. Please try again."
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .noSoftenerFound:
            return "No water softener found on your account."
        }
    }
}

// MARK: - Culligan API Client

/// Actor-based API client for the Culligan IoT API.
/// Thread-safe, handles auth token lifecycle, mirrors the TypeScript `CulliganApi` class.
actor CulliganClient {
    private let baseURL: String
    private let appId: String
    private let timeoutSeconds: TimeInterval
    private let refreshBuffer: TimeInterval

    private var accessToken: String?
    private var refreshToken: String?
    private var expiresAt: Date?

    private let session: URLSession

    init(
        baseURL: String = CulliganConstants.baseURL,
        appId: String = CulliganConstants.appId,
        timeoutSeconds: TimeInterval = CulliganConstants.defaultTimeoutSeconds,
        refreshBuffer: TimeInterval = CulliganConstants.tokenRefreshBufferSeconds
    ) {
        self.baseURL = baseURL
        self.appId = appId
        self.timeoutSeconds = timeoutSeconds
        self.refreshBuffer = refreshBuffer

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds * 2
        self.session = URLSession(configuration: config)

        // Try to restore auth state from keychain
        if let state = KeychainService.loadAuthState() {
            self.accessToken = state.accessToken
            self.refreshToken = state.refreshToken
            self.expiresAt = Date(timeIntervalSince1970: state.expiresAt)
        }
    }

    // MARK: - Authentication

    var isAuthenticated: Bool {
        guard let expiresAt else { return false }
        return accessToken != nil && Date() < expiresAt
    }

    /// Login with email and password
    func login(email: String, password: String) async throws {
        let body = LoginRequest(email: email, password: password, appId: appId)
        let response: ApiResponse<LoginData> = try await request(
            method: "POST",
            endpoint: "/auth/login",
            body: body,
            authenticated: false
        )

        guard response.success, let data = response.data else {
            throw CulliganError.authFailed(response.error?.message ?? "Login failed")
        }

        setTokens(
            access: data.accessToken,
            refresh: data.refreshToken,
            expiresIn: data.expiresIn
        )

        // Save credentials for background refresh
        try? KeychainService.saveCredentials(email: email, password: password)
    }

    /// Refresh the access token
    func refreshAccessToken() async throws {
        guard let refreshToken else {
            throw CulliganError.notAuthenticated
        }

        let body = TokenRefreshRequest(refreshToken: refreshToken, appId: appId)
        let response: ApiResponse<LoginData> = try await request(
            method: "PUT",
            endpoint: "/auth/login",
            body: body,
            authenticated: false
        )

        guard response.success, let data = response.data else {
            throw CulliganError.authFailed(response.error?.message ?? "Token refresh failed")
        }

        setTokens(
            access: data.accessToken,
            refresh: data.refreshToken,
            expiresIn: data.expiresIn
        )
    }

    /// Logout and clear all stored auth
    func logout() {
        accessToken = nil
        refreshToken = nil
        expiresAt = nil
        KeychainService.deleteAll()
    }

    /// Import a previously saved auth state
    func importAuth(_ state: AuthState) {
        accessToken = state.accessToken
        refreshToken = state.refreshToken
        expiresAt = Date(timeIntervalSince1970: state.expiresAt)
    }

    // MARK: - Device Operations

    /// Get all devices from the registry
    func getDeviceRegistry() async throws -> [DeviceRegistryItem] {
        let response: ApiResponse<DeviceRegistryData> = try await request(
            method: "GET",
            endpoint: "/device/registry"
        )
        return response.data?.devices ?? []
    }

    /// Get all softener devices
    func getSofteners() async throws -> [SoftenerDevice] {
        let registry = try await getDeviceRegistry()
        return registry
            .filter { CulliganConstants.softenerNames.contains($0.name) }
            .map { SoftenerDevice(registryItem: $0) }
    }

    /// Get device data (legacy endpoint with property list)
    func getDeviceData(serialNumber: String) async throws -> DeviceData {
        return try await request(
            method: "GET",
            endpoint: "/device/data?serialNumber=\(serialNumber.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? serialNumber)"
        )
    }

    /// Send a command to a device
    func sendCommand(
        serialNumber: String,
        command: String,
        params: [String: CommandParamValue]? = nil,
        protocolVersion: String? = nil
    ) async throws -> CommandResponse {
        let payload = CommandPayload(
            command: command,
            serialNumber: serialNumber,
            protocolVersion: protocolVersion,
            params: params
        )
        return try await request(method: "POST", endpoint: "/device/command", body: payload)
    }

    // MARK: - Softener Commands

    func startVacationMode(serialNumber: String, protocolVersion: String? = nil) async throws -> CommandResponse {
        try await sendCommand(serialNumber: serialNumber, command: "awayMode.set", params: ["active": .int(1)], protocolVersion: protocolVersion)
    }

    func stopVacationMode(serialNumber: String, protocolVersion: String? = nil) async throws -> CommandResponse {
        try await sendCommand(serialNumber: serialNumber, command: "awayMode.set", params: ["active": .int(0)], protocolVersion: protocolVersion)
    }

    func startBypassMode(serialNumber: String, protocolVersion: String? = nil) async throws -> CommandResponse {
        try await sendCommand(serialNumber: serialNumber, command: "bypass.permanent.on", params: ["active": .int(1)], protocolVersion: protocolVersion)
    }

    func startBypassTimed(serialNumber: String, durationSeconds: Int, protocolVersion: String? = nil) async throws -> CommandResponse {
        try await sendCommand(serialNumber: serialNumber, command: "bypass.timed.on", params: ["active": .int(1), "duration": .int(durationSeconds)], protocolVersion: protocolVersion)
    }

    func stopBypassMode(serialNumber: String, protocolVersion: String? = nil) async throws -> CommandResponse {
        try await sendCommand(serialNumber: serialNumber, command: "bypass.off", params: ["active": .int(1)], protocolVersion: protocolVersion)
    }

    func requestTelemetry(serialNumber: String, protocolVersion: String? = nil) async throws -> CommandResponse {
        try await sendCommand(serialNumber: serialNumber, command: "telemetry.get", protocolVersion: protocolVersion)
    }

    // MARK: - Private Helpers

    private func setTokens(access: String, refresh: String, expiresIn: Int) {
        self.accessToken = access
        self.refreshToken = refresh
        self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))

        // Persist to keychain
        let state = AuthState(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn)).timeIntervalSince1970
        )
        try? KeychainService.saveAuthState(state)
    }

    private func ensureAuthenticated() async throws {
        guard let expiresAt, accessToken != nil else {
            throw CulliganError.notAuthenticated
        }

        let timeUntilExpiry = expiresAt.timeIntervalSinceNow

        if timeUntilExpiry <= 0 {
            // Token expired — try refresh
            if refreshToken != nil {
                try await refreshAccessToken()
                return
            }
            throw CulliganError.tokenExpired
        }

        if timeUntilExpiry <= refreshBuffer {
            // Token expiring soon — auto-refresh
            if refreshToken != nil {
                try await refreshAccessToken()
            }
        }
    }

    private func request<T: Decodable>(
        method: String,
        endpoint: String,
        body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        if authenticated {
            try await ensureAuthenticated()
        }

        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw CulliganError.apiError(statusCode: 0, message: "Invalid URL: \(endpoint)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if authenticated, let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw CulliganError.timeout
        } catch {
            throw CulliganError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            // Try to parse a structured error response
            let friendlyMessage: String
            if let errorResponse = try? JSONDecoder().decode(ApiResponse<EmptyData>.self, from: data),
               let apiMessage = errorResponse.error?.message {
                friendlyMessage = Self.friendlyError(for: apiMessage)
            } else {
                friendlyMessage = "Something went wrong. Please try again."
            }

            if httpResponse.statusCode == 401 || httpResponse.statusCode == 422 {
                throw CulliganError.authFailed(friendlyMessage)
            }
            throw CulliganError.apiError(statusCode: httpResponse.statusCode, message: friendlyMessage)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CulliganError.decodingError(error)
        }
    }

    /// Map API error codes to user-friendly messages
    private static func friendlyError(for apiMessage: String) -> String {
        switch apiMessage {
        case "INVALID_PASSWORD":
            return "Incorrect password. Please try again."
        case "USER_NOT_FOUND", "INVALID_EMAIL":
            return "No account found with that email address."
        case "ACCOUNT_LOCKED":
            return "Account locked. Please try again later."
        case "TOO_MANY_REQUESTS":
            return "Too many attempts. Please wait a moment."
        default:
            return apiMessage.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

/// Empty decodable for parsing error-only responses
private struct EmptyData: Decodable, Sendable {}

// MARK: - Softener Device (value type wrapper)

/// A value-type representation of a Culligan water softener, extracted from registry data.
struct SoftenerDevice: Identifiable, Sendable {
    let registryItem: DeviceRegistryItem

    var id: String { serialNumber }
    var serialNumber: String { registryItem.serialNumber }
    var name: String { registryItem.name }
    var model: String? { registryItem.model }

    var isOnline: Bool {
        registryItem.status?.connection?.online ?? false
    }

    var lastUpdate: String? {
        registryItem.status?.connection?.lastUpdate
    }

    var protocolVersion: String? {
        registryItem.protocolVersion.map(String.init)
    }

    private var props: DeviceProperties {
        registryItem.properties ?? DeviceProperties()
    }

    // MARK: - Softener Properties

    var saltLevel: Int? {
        props.intValue(for: "manual_salt_level_rem_calc") ?? props.intValue(for: "salt_level_slm_recent")
    }

    var daysSaltRemaining: Int? {
        props.intValue(for: "days_salt_remaining")
    }

    var currentFlowRate: Double? {
        props.doubleValue(for: "current_flow_rate")
    }

    var waterUsageToday: Double? {
        props.doubleValue(for: "total_water_usage_today_tank_1")
    }

    var totalWaterUsage: Double? {
        props.doubleValue(for: "total_water_usage_since_install_tank_1")
    }

    var isBypassed: Bool {
        props.intValue(for: "actual_state_dealer_bypass") == 1
    }

    var isVacationMode: Bool {
        props.intValue(for: "away_mode") == 1
    }

    var lastRegeneration: String? {
        props.stringValue(for: "last_regen_date_time_tank_1")
    }

    var daysSinceRegeneration: Int? {
        props.intValue(for: "days_since_last_regen_tank_1")
    }

    var nextRegeneration: String? {
        props.stringValue(for: "next_regen_date_time")
    }

    var firmwareVersion: String? {
        props.stringValue(for: "gbx_firmware_version")
    }

    // MARK: - Daily Usage (last 30 days)

    /// Returns daily usage for the last 30 days as (daysAgo, gallons) pairs.
    /// day 1 = today, day 2 = yesterday, etc.
    func dailyUsage() -> [(daysAgo: Int, gallons: Double)] {
        (1...30).compactMap { day in
            let key = "daily_usage_day_\(String(format: "%02d", day))"
            guard let gallons = props.doubleValue(for: key) else { return nil }
            return (daysAgo: day - 1, gallons: gallons)
        }
    }
}
