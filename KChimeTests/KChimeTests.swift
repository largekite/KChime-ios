import XCTest
@testable import KChime

final class ToneDetectorTests: XCTestCase {

    func testWarmDirectDetection() {
        let likes: Set<Int> = [0, 3]   // short, casual samples
        let profile = ToneDetector.detect(from: SampleReply.all, likes: likes)
        XCTAssertEqual(profile.label, "Warm & direct")
        XCTAssertLessThan(profile.formality, 0.5)
    }

    func testFormalDetection() {
        let likes: Set<Int> = [2]      // formal teacher-thank sample
        let profile = ToneDetector.detect(from: SampleReply.all, likes: likes)
        XCTAssertEqual(profile.label, "Formal & brief")
        XCTAssertGreaterThan(profile.formality, 0.6)
    }

    func testNoLikesDefaultsToWarmDirect() {
        let profile = ToneDetector.detect(from: SampleReply.all, likes: [])
        XCTAssertEqual(profile.label, "Warm & direct")
    }
}

final class UsageCacheTests: XCTestCase {

    func testSetAndGet() {
        UsageCache.shared.setUsage(remaining: 3, limit: 5, for: "test-feature")
        let result = UsageCache.shared.cachedUsage(for: "test-feature")
        XCTAssertEqual(result?.remaining, 3)
        XCTAssertEqual(result?.limit, 5)
        UsageCache.shared.invalidate(for: "test-feature")
    }

    func testDecrement() {
        UsageCache.shared.setUsage(remaining: 5, limit: 5, for: "test-decrement")
        UsageCache.shared.decrementLocally(for: "test-decrement")
        XCTAssertEqual(UsageCache.shared.cachedUsage(for: "test-decrement")?.remaining, 4)
        UsageCache.shared.invalidate(for: "test-decrement")
    }

    func testDecrementDoesNotGoBelowZero() {
        UsageCache.shared.setUsage(remaining: 0, limit: 5, for: "test-zero")
        UsageCache.shared.decrementLocally(for: "test-zero")
        XCTAssertEqual(UsageCache.shared.cachedUsage(for: "test-zero")?.remaining, 0)
        UsageCache.shared.invalidate(for: "test-zero")
    }
}

final class EncryptionServiceTests: XCTestCase {

    func testRoundTrip() throws {
        let original = "Mom lives in Phoenix. Allergic to cats."
        let encrypted = try EncryptionService.shared.encrypt(original)
        let decrypted = try EncryptionService.shared.decrypt(encrypted)
        XCTAssertEqual(decrypted, original)
    }

    func testDifferentCiphertextsForSamePlaintext() throws {
        let text = "Hello"
        let a = try EncryptionService.shared.encrypt(text)
        let b = try EncryptionService.shared.encrypt(text)
        XCTAssertNotEqual(a, b, "AES-GCM nonces should make each ciphertext unique")
    }
}
