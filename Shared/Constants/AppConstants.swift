// Shared constants accessible by all targets via App Group

import Foundation

public enum AppConstants {
    public static let appGroupID = "group.com.kchime.shared"
    public static let keychainService = "com.kchime.app"
    public static let apiBaseURL = "https://k-chime-ios.vercel.app"

    public enum UserDefaultsKey {
        public static let toneProfile = "kchime_tone_profile"
        public static let onboardingComplete = "kchime_onboarding_complete"
        public static let privacyAccepted = "kchime_privacy_accepted"
        public static let usageCache = "kchime_usage_cache"
        public static let isProUser = "kchime_is_pro"
        @available(*, deprecated, message: "Max tier removed — use Pro only")
        public static let isMaxUser = "kchime_is_max"
        public static let anonymousDeviceID = "kchime_device_id"
        public static let proExpiresAt = "kchime_pro_expires_at"
        public static let lastUsageResetDate = "kchime_usage_reset_date"
    }

    public enum KeychainKey {
        public static let authToken = "auth_token"
        public static let contactNotesEncryptionKey = "contact_notes_key"
        public static let appleUserID = "apple_user_id"
    }

    public enum Feature {
        public static let keyboard = "keyboard"
        public static let workReply = "work-reply"
        public static let fixMessage = "fix-message"
        public static let shareExtension = "share-extension"

        // Quick Reply limits
        public static let freeLimit  = 10          // quick reply generations / day on free plan
        public static let proLimit   = 50          // quick reply generations / day on pro plan ($7/mo)

        // Work Reply limits
        public static let workFreeLimit = 5        // work reply generations / day on free plan
        public static let workProLimit  = 50       // work reply generations / day on pro plan

        // Fix My Message limits
        public static let fixFreeLimit = 5         // fix message uses / day on free plan
        public static let fixProLimit  = 50        // fix message uses / day on pro plan (effectively unlimited)
    }

}
