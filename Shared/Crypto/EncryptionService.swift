import Foundation
import CryptoKit
import KeychainSwift

/// Encrypts/decrypts contact notes using AES-GCM with a per-device key in the Keychain.
public final class EncryptionService: @unchecked Sendable {
    public static let shared = EncryptionService()
    private let keychain = KeychainSwift()

    private init() {}

    // MARK: - Key Management

    private func symmetricKey() throws -> SymmetricKey {
        if let data = keychain.getData(AppConstants.KeychainKey.contactNotesEncryptionKey) {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        keychain.set(keyData, forKey: AppConstants.KeychainKey.contactNotesEncryptionKey,
                     withAccess: .accessibleWhenUnlockedThisDeviceOnly)
        return key
    }

    // MARK: - Public API

    public func encrypt(_ plaintext: String) throws -> Data {
        let key = try symmetricKey()
        let data = Data(plaintext.utf8)
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.sealFailed
        }
        return combined
    }

    public func decrypt(_ ciphertext: Data) throws -> String {
        let key = try symmetricKey()
        let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
        let decrypted = try AES.GCM.open(sealedBox, using: key)
        guard let result = String(data: decrypted, encoding: .utf8) else {
            throw EncryptionError.decodeFailed
        }
        return result
    }

    public enum EncryptionError: Error {
        case sealFailed
        case decodeFailed
    }
}
