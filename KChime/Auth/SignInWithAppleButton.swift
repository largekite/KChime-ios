import SwiftUI
@preconcurrency import AuthenticationServices

/// Drop-in SwiftUI wrapper for the native Sign in with Apple button.
/// Usage:
///   SignInWithAppleView { authorization in
///       await authService.handleAuthorization(authorization)
///   }
struct SignInWithAppleView: View {
    var onAuthorization: (ASAuthorization) async -> Void

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                Task { await onAuthorization(authorization) }
            case .failure(let error):
                // ASAuthorizationError.canceled is user-initiated — no need to surface
                guard (error as? ASAuthorizationError)?.code != .canceled else { return }
                print("[SignInWithApple] error: \(error.localizedDescription)")
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .cornerRadius(10)
    }
}
