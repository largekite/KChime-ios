// Shared constants accessible by all targets via App Group

import Foundation

public enum AppConstants {
    public static let appGroupID = "group.com.kchime.shared"
    public static let keychainService = "com.kchime.app"
    // Local dev (Simulator):      http://localhost:3000
    // Physical device on same WiFi: http://YOUR_MAC_IP:3000
    // Production: replace with your deployed Hono backend URL
    //             (NOT https://kchime.vercel.app — that is the Next.js web app)
    public static let apiBaseURL = "http://localhost:3000"

    public enum UserDefaultsKey {
        public static let toneProfile = "kchime_tone_profile"
        public static let onboardingComplete = "kchime_onboarding_complete"
        public static let privacyAccepted = "kchime_privacy_accepted"
        public static let usageCache = "kchime_usage_cache"
        public static let isProUser = "kchime_is_pro"
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
        public static let shareExtension = "share-extension"
        public static let freeLimit  = 10          // generations / day on free plan
        public static let proLimit   = 10_000      // effectively unlimited; used as the daily ceiling
    }

    public enum StoreKit {
        public static let proMonthlyProductID = "com.kchime.app.pro.monthly"
        public static let proAnnualProductID  = "com.kchime.app.pro.annual"
        /// RevenueCat entitlement identifier configured in the RC dashboard.
        public static let proEntitlementID    = "pro"
    }

    /// RevenueCat public API key — replace with your project's key from
    /// https://app.revenuecat.com → Project Settings → API Keys.
    public enum RevenueCat {
        public static let publicKey = "appl_REPLACE_WITH_YOUR_KEY"
        /// RC Offering identifier (set in dashboard; "default" is fine).
        public static let offeringID = "default"
    }

}
