import CryptoKit
import XCTest
@testable import KeeForge

final class WatchSnapshotBuilderTests: XCTestCase {
    private let sessionKey = SymmetricKey(size: .bits256)
    private let databaseID = UUID()

    func testSelectsOwnAndInheritedWatchTagsAndSkipsTheRecycleBin() throws {
        let own = entry("Own", tags: ["apple watch"])
        let inherited = entry("Inherited")
        let untagged = entry("Untagged", tags: ["Work"])
        let recycled = entry("Recycled", tags: ["Apple Watch"])
        let recycleBin = KPGroup(name: "Recycle Bin", tags: ["Apple Watch"], entries: [recycled])
        let root = KPGroup(
            name: "Root",
            entries: [own, untagged],
            groups: [
                KPGroup(name: "Watch Group", tags: ["Apple Watch"], entries: [inherited]),
                recycleBin,
            ],
            recycleBinUUID: recycleBin.id
        )

        let snapshot = build(root)

        XCTAssertEqual(snapshot.entries.map(\.title), ["Inherited", "Own"])
        XCTAssertEqual(snapshot.databaseID, databaseID)
        XCTAssertEqual(snapshot.databaseName, "Personal")
    }

    func testDecryptsEveryShownFieldAndTheTOTPSecret() throws {
        let secret = Data("12345678901234567890".utf8)
        let tagged = KPEntry(
            title: "Bank",
            username: "alice",
            password: try EncryptedValue.encrypt("s3cret", using: sessionKey),
            url: "https://bank.example",
            notes: "PIN in the safe",
            tags: ["Apple Watch"],
            totpConfig: TOTPConfig(
                secret: try EncryptedValue.encrypt(TOTPGenerator.base32Encode(secret), using: sessionKey),
                period: 30,
                digits: 8,
                algorithm: .sha1
            )
        )

        let watchEntry = try XCTUnwrap(build(KPGroup(name: "Root", entries: [tagged])).entries.first)

        XCTAssertEqual(watchEntry.username, "alice")
        XCTAssertEqual(watchEntry.password, "s3cret")
        XCTAssertEqual(watchEntry.url, "https://bank.example")
        XCTAssertEqual(watchEntry.notes, "PIN in the safe")
        let totp = try XCTUnwrap(watchEntry.totp)
        XCTAssertEqual(totp.secret, secret)
        XCTAssertEqual(totp.digits, 8)
        XCTAssertEqual(
            TOTPCode.generate(
                key: SymmetricKey(data: totp.secret),
                algorithm: totp.algorithm,
                digits: totp.digits,
                period: totp.period,
                date: Date(timeIntervalSince1970: 59)
            ),
            "94287082"
        )
    }

    func testSyncMessagesRoundTripThroughUserInfo() throws {
        let snapshot = build(KPGroup(name: "Root", entries: [entry("Own", tags: ["Apple Watch"])]))

        let sent = try WatchSyncMessage.snapshot(snapshot).userInfo()
        guard case .snapshot(let received) = WatchSyncMessage(userInfo: sent) else {
            return XCTFail("Snapshot message did not decode")
        }
        XCTAssertEqual(received, snapshot)

        let removal = try WatchSyncMessage.removed(databaseID: databaseID).userInfo()
        XCTAssertEqual(WatchSyncMessage(userInfo: removal)?.databaseID, databaseID)
        XCTAssertNil(WatchSyncMessage(userInfo: ["unrelated": true]))
    }

    private func entry(_ title: String, tags: [String] = []) -> KPEntry {
        KPEntry(title: title, tags: tags)
    }

    private func build(_ root: KPGroup) -> WatchVaultSnapshot {
        WatchSnapshotBuilder.snapshot(root: root, databaseID: databaseID, databaseName: "Personal", sessionKey: sessionKey)
    }
}
