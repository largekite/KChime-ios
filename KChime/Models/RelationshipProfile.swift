import Foundation

// MARK: - Model

/// Describes the relationship between the user and the person they're replying to.
/// All numeric axes are 0–10. Stored/restored via RelationshipProfileStore.
struct RelationshipProfile: Codable, Equatable, Identifiable {
    var id: String          // stable string so built-ins survive re-launch
    var name: String        // "Boss", "Friend", etc.
    var emoji: String       // visual identifier in the picker
    var formality: Int      // 0 (very casual) – 10 (very formal)
    var warmth: Int         // 0 (distant) – 10 (very warm)
    var brevity: Int        // 0 (can be long) – 10 (one sentence max)
    var emojiAllowed: Bool
    var directness: Int     // 0 (gentle, indirect) – 10 (blunt, direct)
    var isCustom: Bool      // true for user-created profiles

    // Convert to the API payload sent with each reply request
    func toPayload() -> RelationshipProfilePayload {
        RelationshipProfilePayload(
            name: name,
            formality: formality,
            warmth: warmth,
            brevity: brevity,
            emojiAllowed: emojiAllowed,
            directness: directness
        )
    }
}

// MARK: - Built-in profiles

extension RelationshipProfile {
    /// The six built-in relationship contexts.
    static let builtIns: [RelationshipProfile] = [
        RelationshipProfile(
            id: "boss",
            name: "Boss",
            emoji: "👔",
            formality: 8,
            warmth: 4,
            brevity: 7,
            emojiAllowed: false,
            directness: 7,
            isCustom: false
        ),
        RelationshipProfile(
            id: "coworker",
            name: "Coworker",
            emoji: "💼",
            formality: 5,
            warmth: 6,
            brevity: 6,
            emojiAllowed: false,
            directness: 6,
            isCustom: false
        ),
        RelationshipProfile(
            id: "client",
            name: "Client",
            emoji: "🤝",
            formality: 7,
            warmth: 6,
            brevity: 7,
            emojiAllowed: false,
            directness: 6,
            isCustom: false
        ),
        RelationshipProfile(
            id: "teacher",
            name: "Teacher",
            emoji: "📚",
            formality: 7,
            warmth: 5,
            brevity: 6,
            emojiAllowed: false,
            directness: 5,
            isCustom: false
        ),
        RelationshipProfile(
            id: "friend",
            name: "Friend",
            emoji: "👫",
            formality: 2,
            warmth: 9,
            brevity: 4,
            emojiAllowed: true,
            directness: 7,
            isCustom: false
        ),
        RelationshipProfile(
            id: "family",
            name: "Family",
            emoji: "❤️",
            formality: 1,
            warmth: 10,
            brevity: 5,
            emojiAllowed: true,
            directness: 8,
            isCustom: false
        ),
    ]
}

// MARK: - Persistence

/// Reads and writes the selected (last-used) relationship profile ID via the
/// shared App Group UserDefaults so both the main app and keyboard extension
/// stay in sync without a CoreData MOC.
final class RelationshipProfileStore {
    nonisolated(unsafe) static let shared = RelationshipProfileStore()

    private let defaults: UserDefaults
    private let selectedIDKey = "kchime_selected_relationship_id"
    private let customProfilesKey = "kchime_custom_relationship_profiles"

    private init() {
        defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    // MARK: - Selected profile

    /// The last-used profile, or nil for "no relationship context".
    var selectedProfile: RelationshipProfile? {
        get {
            guard let id = defaults.string(forKey: selectedIDKey) else { return nil }
            return allProfiles.first { $0.id == id }
        }
        set {
            if let profile = newValue {
                defaults.set(profile.id, forKey: selectedIDKey)
            } else {
                defaults.removeObject(forKey: selectedIDKey)
            }
        }
    }

    // MARK: - All profiles (built-ins + custom)

    var allProfiles: [RelationshipProfile] {
        RelationshipProfile.builtIns + customProfiles
    }

    /// Convenience accessor used by onboarding views.
    var builtIns: [RelationshipProfile] { RelationshipProfile.builtIns }

    // MARK: - Custom profiles

    var customProfiles: [RelationshipProfile] {
        guard let data = defaults.data(forKey: customProfilesKey),
              let profiles = try? JSONDecoder().decode([RelationshipProfile].self, from: data)
        else { return [] }
        return profiles
    }

    func saveCustomProfile(_ profile: RelationshipProfile) {
        var custom = customProfiles
        if let idx = custom.firstIndex(where: { $0.id == profile.id }) {
            custom[idx] = profile
        } else {
            custom.append(profile)
        }
        encode(custom, forKey: customProfilesKey)
    }

    func deleteCustomProfile(id: String) {
        var custom = customProfiles.filter { $0.id != id }
        encode(custom, forKey: customProfilesKey)
        if selectedProfile?.id == id {
            selectedProfile = nil
        }
    }

    private func encode(_ value: some Encodable, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
