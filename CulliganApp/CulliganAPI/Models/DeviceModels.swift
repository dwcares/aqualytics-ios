import Foundation

// MARK: - Device Registry

struct DeviceRegistryData: Decodable, Sendable {
    let devices: [DeviceRegistryItem]
}

struct DeviceRegistryItem: Decodable, Identifiable, Sendable {
    var id: String { serialNumber }

    let serialNumber: String
    let name: String
    let model: String?
    let generation: Int?
    let protocolVersion: Int?
    let swVersion: String?
    let status: DeviceStatus?
    let region: DeviceRegion?
    let metaData: [String: String]?
    let registeredAt: String?
    let createdAt: String?
    let updatedAt: String?
    let currentUserRole: String?
    let dealerId: String?
    let accountNumber: String?
    let installationAddress: DeviceInstallationAddress?
    let contactInfo: DeviceContactInfo?
    let properties: DeviceProperties?
}

// MARK: - Device Status

struct DeviceStatus: Decodable, Sendable {
    let connection: DeviceConnectionStatus?
}

struct DeviceConnectionStatus: Decodable, Sendable {
    let online: Bool?
    let lastUpdate: String?
    let hub: String?
    let checkAfter: Int?
}

struct DeviceRegion: Decodable, Sendable {
    let code: String
}

struct DeviceInstallationAddress: Decodable, Sendable {
    let address: String?
    let addressExtra: String?
    let zip: String?
    let city: String?
    let state: String?
    let country: String?
}

struct DeviceContactInfo: Decodable, Sendable {
    let email: String?
    let name: String?
    let phoneNumber: String?
}

// MARK: - Device Properties

/// Flat key-value map from the API. Uses dynamic member lookup for typed access.
struct DeviceProperties: Decodable, Sendable {
    private let values: [String: PropertyValue]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var dict: [String: PropertyValue] = [:]
        for key in container.allKeys {
            if let intVal = try? container.decode(Int.self, forKey: key) {
                dict[key.stringValue] = .int(intVal)
            } else if let doubleVal = try? container.decode(Double.self, forKey: key) {
                dict[key.stringValue] = .double(doubleVal)
            } else if let stringVal = try? container.decode(String.self, forKey: key) {
                dict[key.stringValue] = .string(stringVal)
            } else {
                dict[key.stringValue] = .null
            }
        }
        self.values = dict
    }

    init() {
        self.values = [:]
    }

    func intValue(for key: String) -> Int? {
        switch values[key] {
        case .int(let v): return v
        case .double(let v): return Int(v)
        default: return nil
        }
    }

    func doubleValue(for key: String) -> Double? {
        switch values[key] {
        case .double(let v): return v
        case .int(let v): return Double(v)
        default: return nil
        }
    }

    func stringValue(for key: String) -> String? {
        switch values[key] {
        case .string(let v): return v
        default: return nil
        }
    }

    subscript(key: String) -> PropertyValue? {
        values[key]
    }
}

enum PropertyValue: Decodable, Sendable {
    case int(Int)
    case double(Double)
    case string(String)
    case null

    var asDouble: Double? {
        switch self {
        case .int(let v): return Double(v)
        case .double(let v): return v
        default: return nil
        }
    }

    var asInt: Int? {
        switch self {
        case .int(let v): return v
        case .double(let v): return Int(v)
        default: return nil
        }
    }

    var asString: String? {
        switch self {
        case .string(let v): return v
        default: return nil
        }
    }
}

// MARK: - Device Data (legacy /device/data endpoint)

struct DeviceData: Decodable, Sendable {
    let serialNumber: String
    let properties: [DeviceProperty]
    let lastUpdate: String?
}

struct DeviceProperty: Decodable, Sendable {
    let name: String
    let value: PropertyValue?
    let displayName: String?
    let unit: String?
    let writable: Bool?
}

// MARK: - Dynamic Coding Key

struct DynamicCodingKey: CodingKey, Sendable {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

// MARK: - Known Softener Names

enum CulliganConstants {
    static let baseURL = "https://uniapi.culliganiot.com/api/v1"
    static let appId = "OAhRjZjfBSwKLV8MTCjscAdoyJKzjxQW"
    static let tokenRefreshBufferSeconds: TimeInterval = 600 // 10 minutes
    static let defaultTimeoutSeconds: TimeInterval = 30
    static let softenerNames = ["Smart HE", "Smart Modernity"]
}
