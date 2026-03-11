@preconcurrency import AuthenticationServices
import KeychainSwift
import Foundation

/// Handles Sign in with Apple credential flow and exchanges the Apple identity
/// token for a KChime session JWT via the backend.
@MainActor
final class SignInWithAppleService: NSObject, ObservableObject {

    nonisolated(unsafe) static let shared = SignInWithAppleService()

    @Published var isSignedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let keychain = KeychainSwift()
    private let api = KChimeAPIClient.shared

    // MARK: - State

    override init() {
        super.init()
        // Restore signed-in state from keychain
        isSignedIn = keychain.get(AppConstants.KeychainKey.authToken) != nil
    }

    // MARK: - Sign In

    /// Call from a `SignInWithAppleButton` `.onRequest` / `.onCompletion` pair.
    func handleAuthorization(_ authorization: ASAuthorization) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authCodeData = credential.authorizationCode,
              let authorizationCode = String(data: authCodeData, encoding: .utf8)
        else {
            errorMessage = "Sign in with Apple returned invalid credentials."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await api.signInWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                givenName: credential.fullName?.givenName,
                familyName: credential.fullName?.familyName
            )

            keychain.set(response.token, forKey: AppConstants.KeychainKey.authToken,
                         withAccess: .accessibleWhenUnlockedThisDeviceOnly)
            keychain.set(credential.user, forKey: AppConstants.KeychainKey.appleUserID,
                         withAccess: .accessibleWhenUnlockedThisDeviceOnly)
            // Sync tier from the server — this is the single source of truth.
            EntitlementStore.shared.sync(isPro: response.isPro, isMax: response.isMax, expiresAt: nil)
            isSignedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() {
        keychain.delete(AppConstants.KeychainKey.authToken)
        keychain.delete(AppConstants.KeychainKey.appleUserID)
        isSignedIn = false
    }

    // MARK: - Credential State Check

    func checkCredentialState() async {
        guard let appleUserID = keychain.get(AppConstants.KeychainKey.appleUserID) else {
            signOut()
            return
        }
        let state = await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider()
                .getCredentialState(forUserID: appleUserID) { state, _ in
                    continuation.resume(returning: state)
                }
        }
        if state == .revoked || state == .notFound {
            signOut()
        }
    }
}
