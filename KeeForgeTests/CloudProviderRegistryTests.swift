import XCTest
@testable import KeeForge

@MainActor
final class CloudProviderRegistryTests: XCTestCase {
    func testAvailableProvidersContainsCloudProviders() {
        XCTAssertEqual(CloudProviderRegistry.availableProviders, [.webDAV, .ftp])
    }

    func testCloudProviderPlatformAvailability() {
        XCTAssertFalse(CloudProviderKind.dropbox.isAvailableOnCurrentPlatform)
        XCTAssertFalse(CloudProviderKind.oneDrive.isAvailableOnCurrentPlatform)
        XCTAssertTrue(CloudProviderKind.webDAV.isAvailableOnCurrentPlatform)
        XCTAssertTrue(CloudProviderKind.ftp.isAvailableOnCurrentPlatform)
    }

    func testProviderResolutionStaysUnfilteredForHiddenProviders() {
        #if os(macOS)
        // The Mac app does not compile either provider, so resolution is not
        // merely filtered — the types are absent. Nothing can have connected
        // one, because neither has ever been reachable from the Mac UI.
        XCTAssertNil(CloudProviderRegistry.provider(for: CloudProviderKind.dropbox.rawValue))
        XCTAssertNil(CloudProviderRegistry.provider(for: CloudProviderKind.oneDrive.rawValue))
        #else
        // The UI gate must not affect provider(for:) resolution: an
        // already-connected Dropbox/OneDrive database must still resolve its
        // provider (and therefore stay openable) even on platforms where the
        // provider is hidden from the add/import UI.
        XCTAssertNotNil(CloudProviderRegistry.provider(for: CloudProviderKind.dropbox.rawValue))
        XCTAssertNotNil(CloudProviderRegistry.provider(for: CloudProviderKind.oneDrive.rawValue))
        #endif
        XCTAssertNotNil(CloudProviderRegistry.provider(for: CloudProviderKind.webDAV.rawValue))
    }

    #if !os(macOS)
    func testProviderReturnsDropboxSharedInstance() {
        let provider = CloudProviderRegistry.provider(for: CloudProviderKind.dropbox.rawValue)

        XCTAssertTrue(provider === DropboxCloudProvider.shared)
    }

    func testProviderReturnsOneDriveSharedInstance() {
        let provider = CloudProviderRegistry.provider(for: CloudProviderKind.oneDrive.rawValue)

        XCTAssertTrue(provider === OneDriveCloudProvider.shared)
    }
    #endif

    func testProviderReturnsWebDAVSharedInstance() {
        let provider = CloudProviderRegistry.provider(for: CloudProviderKind.webDAV.rawValue)

        XCTAssertTrue(provider === WebDAVCloudProvider.shared)
    }

    func testProviderReturnsFTPSharedInstance() {
        let provider = CloudProviderRegistry.provider(for: CloudProviderKind.ftp.rawValue)

        XCTAssertTrue(provider === FTPCloudProvider.shared)
    }

    func testProviderReturnsNilForUnknownProvider() {
        XCTAssertNil(CloudProviderRegistry.provider(for: "unknown"))
    }

    func testHandleOpenURLReturnsFalseForNonDropboxURL() {
        let url = URL(string: "https://example.com/callback")!

        XCTAssertFalse(CloudProviderRegistry.handleOpenURL(url))
    }
}
