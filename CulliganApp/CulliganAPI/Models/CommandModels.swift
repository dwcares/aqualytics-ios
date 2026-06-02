import Foundation

// MARK: - Command Models

struct CommandPayload: Encodable, Sendable {
    let command: String
    let serialNumber: String
    let protocolVersion: String?
    let params: [String: CommandParamValue]?
}

enum CommandParamValue: Encodable, Sendable {
    case int(Int)
    case string(String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        }
    }
}

struct CommandResponse: Decodable, Sendable {
    let success: Bool
    let message: String?
}
