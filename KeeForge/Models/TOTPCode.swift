import CryptoKit
import Foundation

enum TOTPAlgorithm: String, Codable, Sendable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
}

/// RFC 6238 code computation over a plaintext key. Kept free of the KDBX model
/// and session crypto so the Watch app compiles it on its own.
enum TOTPCode {
    static func generate(
        key: SymmetricKey,
        algorithm: TOTPAlgorithm,
        digits: Int,
        period: Int,
        date: Date = Date()
    ) -> String {
        // Parsers sanitize file-supplied values, but configs can also arrive
        // from edit drafts: clamp so a rogue period can never divide by zero
        // (or trap converting a negative to UInt64) and a rogue digit count
        // can never overflow the 10^digits modulus below.
        let period = UInt64(max(1, period))
        let digits = min(max(digits, 1), 9)

        let timeInterval = UInt64(date.timeIntervalSince1970)
        let counter = timeInterval / period

        var bigEndianCounter = counter.bigEndian
        let counterData = Data(bytes: &bigEndianCounter, count: 8)

        let hmac: Data
        switch algorithm {
        case .sha1:
            var h = HMAC<Insecure.SHA1>.init(key: key)
            h.update(data: counterData)
            hmac = Data(h.finalize())
        case .sha256:
            hmac = Data(HMAC<SHA256>.authenticationCode(for: counterData, using: key))
        case .sha512:
            hmac = Data(HMAC<SHA512>.authenticationCode(for: counterData, using: key))
        }

        let offset = Int(hmac[hmac.count - 1] & 0x0F)
        let truncated = hmac.withUnsafeBytes { ptr -> UInt32 in
            ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian & 0x7FFF_FFFF
        }

        let modulus = UInt32(pow(10.0, Double(digits)))
        let code = truncated % modulus
        return String(format: "%0\(digits)d", code)
    }

    /// Seconds remaining in the current TOTP period.
    static func secondsRemaining(period: Int, date: Date = Date()) -> Int {
        let period = max(1, period)
        let elapsed = Int(date.timeIntervalSince1970) % period
        return period - elapsed
    }
}
