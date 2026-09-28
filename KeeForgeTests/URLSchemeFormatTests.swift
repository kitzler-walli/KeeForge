import XCTest
@testable import KeeForge

/// Guards against ITMS-90158: an illegal URL scheme is only rejected by App Store
/// Connect after the archive has been uploaded. The unit tests are hosted by the
/// app, so `Bundle.main` here is the app bundle with build settings substituted.
final class URLSchemeFormatTests: XCTestCase {
    /// RFC1738 §2.1: scheme = alphanumeric, then alphanumerics, "+", "-", ".".
    private static let validScheme = try! NSRegularExpression(
        pattern: "^[A-Za-z][A-Za-z0-9+.-]*$"
    )

    func testDeclaredURLSchemesAreRFC1738Compliant() throws {
        let schemes = try declaredURLSchemes()
        XCTAssertFalse(schemes.isEmpty, "Expected the app bundle to declare at least one URL scheme")

        for scheme in schemes {
            let range = NSRange(scheme.startIndex..., in: scheme)
            XCTAssertNotNil(
                Self.validScheme.firstMatch(in: scheme, range: range),
                "URL scheme '\(scheme)' is not RFC1738-compliant; App Store Connect rejects it with ITMS-90158"
            )
        }
    }

    /// Dropbox and OneDrive are hidden and unregistered, so the app must not
    /// advertise OAuth callback schemes nothing can service.
    func testBundleDeclaresNoOAuthSchemes() throws {
        let schemes = try declaredURLSchemes()

        XCTAssertTrue(schemes.filter { $0.hasPrefix("db-") }.isEmpty)
        XCTAssertTrue(schemes.filter { $0.hasPrefix("msauth") }.isEmpty)
    }

    private func declaredURLSchemes() throws -> [String] {
        let urlTypes = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]],
            "Missing CFBundleURLTypes in the host app bundle"
        )

        return urlTypes.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
    }
}
