import Foundation
import KeychainSwift

// MARK: - Models

public struct ReplyRequest: Encodable {
    public let featureKey: String
    public let receivedMessage: String
    public let toneProfile: ToneProfilePayload
    public let contactNotes: String?
    public let deviceID: String

    public init(
        featureKey: String,
        receivedMessage: String,
        toneProfile: ToneProfilePayload,
        contactNotes: String? = nil
    ) {
        self.featureKey = featureKey
        self.receivedMessage = receivedMessage
        self.toneProfile = toneProfile
        self.contactNotes = contactNotes
        self.deviceID = KChimeAPIClient.deviceID
    }
}

public struct ToneProfilePayload: Encodable {
    public let label: String
    public let formality: Double
    public let emojiEnabled: Bool
    public let lengthPreference: String
    public let customInstructions: String?

    public init(
        label: String,
        formality: Double,
        emojiEnabled: Bool,
        lengthPreference: String,
        customInstructions: String? = nil
    ) {
        self.label = label
        self.formality = formality
        self.emojiEnabled = emojiEnabled
        self.lengthPreference = lengthPreference
        self.customInstructions = customInstructions
    }
}

public struct ReplyResponse: Decodable {
    public let suggestions: [String]
    public let remaining: Int
    public let limit: Int
}

public struct APIError: Decodable, Error {
    public let error: String
    public let code: String?
}

// MARK: - Client

public final class KChimeAPIClient: @unchecked Sendable {
    public static let shared = KChimeAPIClient()

    private let session: URLSession
    private let keychain = KeychainSwift()

    // Stable anonymous device ID, created once and persisted
    public static var deviceID: String {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID)!
        if let existing = defaults.string(forKey: AppConstants.UserDefaultsKey.anonymousDeviceID) {
            return existing
        }
        let new = UUID().uuidString
        defaults.set(new, forKey: AppConstants.UserDefaultsKey.anonymousDeviceID)
        return new
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Reply Generation

    public func generateReplies(request: ReplyRequest) async throws -> ReplyResponse {
        let url = URL(string: "\(AppConstants.apiBaseURL)/api/mobile/reply")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = keychain.get(AppConstants.KeychainKey.authToken) {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(ReplyResponse.self, from: data)
        case 401:
            throw KChimeError.unauthenticated
        case 429:
            throw KChimeError.limitReached
        default:
            let apiErr = try? JSONDecoder().decode(APIError.self, from: data)
            throw KChimeError.unknown(apiErr?.error ?? "HTTP \(http.statusCode)")
        }
    }

    // MARK: - Usage

    public func fetchUsage(featureKey: String) async throws -> (remaining: Int, limit: Int) {
        let url = URL(string: "\(AppConstants.apiBaseURL)/api/mobile/usage?feature=\(featureKey)&deviceID=\(Self.deviceID)")!
        var urlRequest = URLRequest(url: url)
        if let token = keychain.get(AppConstants.KeychainKey.authToken) {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await session.data(for: urlRequest)
        let result = try JSONDecoder().decode(ReplyResponse.self, from: data)
        return (result.remaining, result.limit)
    }

    // MARK: - Account deletion

    @discardableResult
    public func deleteAccount() async throws -> Bool {
        let url = URL(string: "\(AppConstants.apiBaseURL)/api/mobile/account")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        if let token = keychain.get(AppConstants.KeychainKey.authToken) {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            // Anonymous deletion by device ID
            urlRequest.setValue(Self.deviceID, forHTTPHeaderField: "X-Device-ID")
        }
        let (_, response) = try await session.data(for: urlRequest)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
}

// MARK: - Errors

public enum KChimeError: Error, LocalizedError {
    case unauthenticated
    case limitReached
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .unauthenticated: return "Sign in to use KChime."
        case .limitReached: return "Daily limit reached. Upgrade to Pro for unlimited replies."
        case .unknown(let msg): return msg
        }
    }
}
