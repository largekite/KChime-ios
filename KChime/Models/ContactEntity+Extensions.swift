@preconcurrency import CoreData

// MARK: - Encryption helpers on the CoreData entity

extension ContactEntity {
    /// Stores notes encrypted via AES-GCM. Throws on encryption failure.
    func setEncryptedNotes(_ plaintext: String) throws {
        notesEncrypted = try EncryptionService.shared.encrypt(plaintext)
    }

    /// Returns decrypted notes, or nil if nothing stored or decryption fails.
    func decryptedNotes() -> String? {
        guard let data = notesEncrypted else { return nil }
        return try? EncryptionService.shared.decrypt(data)
    }
}
