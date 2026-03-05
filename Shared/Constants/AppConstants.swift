// Shared constants accessible by all targets via App Group

import Foundation

public enum AppConstants {
    public static let appGroupID = "group.com.kchime.shared"
    public static let keychainService = "com.kchime.app"
    public static let apiBaseURL = "https://kchime.vercel.app"  // update for production

    public enum UserDefaultsKey {
        public static let toneProfile = "kchime_tone_profile"
        public static let onboardingComplete = "kchime_onboarding_complete"
        public static let privacyAccepted = "kchime_privacy_accepted"
        public static let usageCache = "kchime_usage_cache"
        public static let isProUser = "kchime_is_pro"
        public static let anonymousDeviceID = "kchime_device_id"
    }

    public enum KeychainKey {
        public static let authToken = "auth_token"
        public static let contactNotesEncryptionKey = "contact_notes_key"
        public static let appleUserID = "apple_user_id"
    }

    public enum Feature {
        public static let keyboard = "keyboard"
        public static let shareExtension = "share-extension"
        public static let freeLimit = 5
    }

    public enum StoreKit {
        public static let proMonthlyProductID = "com.kchime.app.pro.monthly"
    }
}
