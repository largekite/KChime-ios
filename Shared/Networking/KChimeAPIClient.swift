import Foundation
import KeychainSwift

// MARK: - Models

/// Describes the recipient relationship; sent alongside ToneProfilePayload.
/// All numeric axes are 0–10, mirroring RelationshipProfile.
public struct RelationshipProfilePayload: Encodable {
    public let name: String
    public let formality: Int      // 0–10
    public let warmth: Int         // 0–10
    public let brevity: Int        // 0–10
    public let emojiAllowed: Bool
    public let directness: Int     // 0–10

    public init(name: String, formality: Int, warmth: Int, brevity: Int,
                emojiAllowed: Bool, directness: Int) {
        self.name = name
        self.formality = formality
        self.warmth = warmth
        self.brevity = brevity
        self.emojiAllowed = emojiAllowed
        self.directness = directness
    }
}

public struct ReplyRequest: Encodable {
    public let featureKey: String
    public let receivedMessage: String
    public let toneProfile: ToneProfilePayload
    public let relationshipProfile: RelationshipProfilePayload?
    public let contactNotes: String?
    public let deviceID: String
    public let contextMode: String?   // e.g. "office", "party", "family"

    public init(
        featureKey: String,
        receivedMessage: String,
        toneProfile: ToneProfilePayload,
        relationshipProfile: RelationshipProfilePayload? = nil,
        contactNotes: String? = nil,
        contextMode: String? = nil
    ) {
        self.featureKey = featureKey
        self.receivedMessage = receivedMessage
        self.toneProfile = toneProfile
        self.relationshipProfile = relationshipProfile
        self.contactNotes = contactNotes
        self.contextMode = contextMode
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

public struct ReplyResponse: Decodable, Sendable {
    public let suggestions: [String]
    public let longerAlternative: String
    public let remaining: Int
    public let limit: Int
}

/// Separate struct for the /usage endpoint which does not return suggestions.
public struct UsageResponse: Decodable {
    public let remaining: Int
    public let limit: Int
    public let feature: String
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
        let result = try JSONDecoder().decode(UsageResponse.self, from: data)
        return (result.remaining, result.limit)
    }

    // MARK: - Sign in with Apple

    public struct AuthResponse: Decodable {
        public let token: String
        public let isPro: Bool
        public let isMax: Bool
        public let isNewUser: Bool
    }

    public func signInWithApple(
        identityToken: String,
        authorizationCode: String,
        givenName: String? = nil,
        familyName: String? = nil
    ) async throws -> AuthResponse {
        let url = URL(string: "\(AppConstants.apiBaseURL)/api/auth/apple")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any?] = [
            "identityToken": identityToken,
            "authorizationCode": authorizationCode,
            "deviceID": Self.deviceID,
            "fullName": (givenName != nil || familyName != nil)
                ? ["givenName": givenName, "familyName": familyName]
                : nil,
        ]
        urlRequest.httpBody = try JSONSerialization.data(
            withJSONObject: body.compactMapValues { $0 }
        )

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard http.statusCode == 200 else {
            let apiErr = try? JSONDecoder().decode(APIError.self, from: data)
            throw KChimeError.unknown(apiErr?.error ?? "Auth failed: HTTP \(http.statusCode)")
        }
        return try JSONDecoder().decode(AuthResponse.self, from: data)
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
        case .limitReached: return "Daily limit reached. Upgrade to Pro for 50 replies/day."
        case .unknown(let msg): return msg
        }
    }
}
