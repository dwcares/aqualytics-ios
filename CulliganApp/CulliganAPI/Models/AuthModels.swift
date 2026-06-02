import Foundation

// MARK: - Request Models

struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
    let appId: String
}

struct TokenRefreshRequest: Encodable, Sendable {
    let refreshToken: String
    let appId: String
}

// MARK: - Response Models

struct ApiResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let success: Bool
    let data: T?
    let error: ApiErrorInfo?
}

struct ApiErrorInfo: Decodable, Sendable {
    let message: String
}

struct LoginData: Decodable, Sendable {
    let userId: String
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int // seconds
    let roles: [String]?
    let tenantId: String?
}

// MARK: - Auth State (for persistence)

struct AuthState: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: TimeInterval // Unix timestamp in seconds
}
