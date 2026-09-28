import CryptoKit
import XCTest
@testable import KeeForge

final class EntryMergerTests: XCTestCase {
    private let sessionKey = SymmetricKey(size: .bits256)

    func testTargetKeepsItsValuesAndFillsOnlyEmptyOnes() throws {
        let target = try entry(title: "PayPal", username: "", password: "target-pw", url: "https://paypal.com")
        let source = try entry(title: "paypal.com", username: "alice@example.com", password: "source-pw", url: "https://www.paypal.com")

        let result = try EntryMerger.merge(source, into: target, sessionKey: sessionKey)

        XCTAssertEqual(result.draft.title, "PayPal")
        XCTAssertEqual(result.draft.password, "target-pw")
        XCTAssertEqual(result.draft.url, "https://paypal.com")
        XCTAssertEqual(result.draft.username, "alice@example.com")
        XCTAssertTrue(result.additions.contains(.username))
        XCTAssertFalse(result.additions.contains(.password))
    }

    func testSourceAddressesBecomeAdditionalURLsWithoutDuplicates() throws {
        let target = try entry(title: "Target", url: "https://example.com/", customFields: ["KP2A_URL_1": "https://a.example.com"])
        let source = try entry(
            title: "Source",
            url: "https://example.com",
            customFields: ["KP2A_URL_1": "https://b.example.com", "KP2A_URL_2": "https://a.example.com"]
        )

        let result = try EntryMerger.merge(source, into: target, sessionKey: sessionKey)

        XCTAssertEqual(result.draft.customFields["KP2A_URL_2"], "https://b.example.com")
        XCTAssertNil(result.draft.customFields["KP2A_URL_3"])
        XCTAssertTrue(result.additions.contains(.urls(count: 1)))
    }

    func testConflictingCustomFieldIsKeptUnderTheSourceName() throws {
        let target = try entry(title: "Target", customFields: ["PIN": "1111"])
        var source = try entry(title: "Old", customFields: ["PIN": "2222", "Recovery": "abc"])
        source.protectedStringKeys = ["PIN"]

        let result = try EntryMerger.merge(source, into: target, sessionKey: sessionKey)

        XCTAssertEqual(result.draft.customFields["PIN"], "1111")
        XCTAssertEqual(result.draft.customFields["PIN (Old)"], "2222")
        XCTAssertEqual(result.draft.customFields["Recovery"], "abc")
        XCTAssertTrue(result.draft.protectedCustomFieldKeys.contains("PIN (Old)"))
    }

    func testNotesAreAppendedOnce() throws {
        let target = try entry(title: "Target", notes: "security questions")
        let source = try entry(title: "Source", notes: "recovery codes")

        let merged = try EntryMerger.merge(source, into: target, sessionKey: sessionKey)
        XCTAssertEqual(merged.draft.notes, "security questions\n\nrecovery codes")

        let alreadyThere = try entry(title: "Source", notes: "security questions")
        XCTAssertFalse(try EntryMerger.merge(alreadyThere, into: target, sessionKey: sessionKey).additions.contains(.notes))
    }

    func testPasskeyMovesToTheTargetWithItsPrivateKey() throws {
        let target = try entry(title: "Login", username: "alice@example.com", password: "pw")
        let source = try passkeyEntry()

        let result = try EntryMerger.merge(source, into: target, sessionKey: sessionKey)

        XCTAssertTrue(result.additions.contains(.passkey))
        XCTAssertEqual(result.draft.customFields[PasskeyCredential.privateKeyPEMKey], "PEM")
        XCTAssertEqual(result.draft.customFields[PasskeyCredential.relyingPartyKey], "example.com")
        XCTAssertTrue(result.draft.protectedCustomFieldKeys.isSuperset(of: PasskeyCredential.protectedFieldKeys))
    }

    func testTwoPasskeysCannotBeMerged() throws {
        XCTAssertThrowsError(try EntryMerger.merge(try passkeyEntry(), into: try passkeyEntry(), sessionKey: sessionKey)) { error in
            XCTAssertEqual(error as? EntryMerger.Failure, .bothHavePasskeys)
        }
    }

    func testVerificationCodeMovesOnlyWhenTheTargetHasNone() throws {
        let target = try entry(title: "Target")
        var source = try entry(title: "Source")
        source.totpConfig = TOTPConfig(secret: try EncryptedValue.encrypt("JBSWY3DPEHPK3PXP", using: sessionKey), period: 30, digits: 6, algorithm: .sha1)

        let result = try EntryMerger.merge(source, into: target, sessionKey: sessionKey)

        XCTAssertEqual(result.draft.totpConfig?.secret, "JBSWY3DPEHPK3PXP")
        XCTAssertTrue(result.additions.contains(.verificationCode))
    }

    func testTagsAreUnitedCaseInsensitively() throws {
        let target = try entry(title: "Target", tags: ["Finance"])
        let source = try entry(title: "Source", tags: ["finance", "Apple Watch"])

        let result = try EntryMerger.merge(source, into: target, sessionKey: sessionKey)

        XCTAssertEqual(result.draft.tags, ["Finance", "Apple Watch"])
    }

    // MARK: - Helpers

    private func entry(
        title: String,
        username: String = "",
        password: String = "",
        url: String = "",
        notes: String = "",
        customFields: [String: String] = [:],
        tags: [String] = []
    ) throws -> KPEntry {
        KPEntry(
            title: title,
            username: username,
            password: try EncryptedValue.encrypt(password, using: sessionKey),
            url: url,
            notes: notes,
            tags: tags,
            customFields: customFields
        )
    }

    private func passkeyEntry() throws -> KPEntry {
        KPEntry(
            title: "example.com",
            url: "https://example.com",
            customFields: [
                PasskeyCredential.credentialIDKey: "dGVzdC1jcmVkZW50aWFsLWlk",
                PasskeyCredential.relyingPartyKey: "example.com",
                PasskeyCredential.usernameKey: "alice@example.com",
                PasskeyCredential.userHandleKey: "dXNlci1oYW5kbGU",
            ],
            passkeyPrivateKey: try EncryptedValue.encrypt("PEM", using: sessionKey)
        )
    }
}
