import CryptoKit
import Foundation

/// Folds one entry into another for "Merge Into…": the target keeps every
/// value it has and gains what it lacks from the source. The caller applies
/// the result as an `.updateEntry` of the target (whose previous version goes
/// to history) and sends the source to the recycle bin, so nothing is lost.
enum EntryMerger {
    enum Addition: Equatable, Sendable {
        case username
        case password
        case notes
        case urls(count: Int)
        case customFields([String])
        case passkey
        case verificationCode
        case tags([String])
    }

    enum Failure: Error, Equatable {
        /// An entry stores a single passkey.
        case bothHavePasskeys
    }

    struct Result: Sendable {
        let draft: EntryDraftPayload
        let additions: [Addition]
    }

    private static let additionalURLPrefix = "KP2A_URL_"
    /// Fields that carry a verification code in some format; the code moves
    /// through `totpConfig` instead.
    private static let totpFieldNames: Set<String> = ["TOTP Seed", "TOTP Settings", "otp"]

    static func merge(_ source: KPEntry, into target: KPEntry, sessionKey: SymmetricKey) throws -> Result {
        if source.hasPasskey, target.hasPasskey {
            throw Failure.bothHavePasskeys
        }
        var additions: [Addition] = []

        var username = target.username
        if username.isEmpty, source.username.isEmpty == false {
            username = source.username
            additions.append(.username)
        }

        var password = try target.password.decrypt(using: sessionKey)
        if password.isEmpty {
            let sourcePassword = try source.password.decrypt(using: sessionKey)
            if sourcePassword.isEmpty == false {
                password = sourcePassword
                additions.append(.password)
            }
        }

        var notes = target.notes
        let sourceNotes = source.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if sourceNotes.isEmpty == false, notes.contains(sourceNotes) == false {
            notes = notes.isEmpty ? source.notes : notes + "\n\n" + source.notes
            additions.append(.notes)
        }

        var customFields = target.customFields
        var protectedKeys = target.protectedStringKeys.intersection(customFields.keys)

        var url = target.url
        var knownURLs = Set(([target.url] + target.additionalURLs).map(normalizedURL))
        var addedURLCount = 0
        for sourceURL in [source.url] + source.additionalURLs where sourceURL.isEmpty == false {
            guard knownURLs.insert(normalizedURL(sourceURL)).inserted else { continue }
            if url.isEmpty {
                url = sourceURL
            } else {
                var index = 1
                while customFields["\(additionalURLPrefix)\(index)"] != nil { index += 1 }
                customFields["\(additionalURLPrefix)\(index)"] = sourceURL
            }
            addedURLCount += 1
        }
        if addedURLCount > 0 {
            additions.append(.urls(count: addedURLCount))
        }

        var addedFieldNames: [String] = []
        let sourceOTPField = source.totpConfig?.keeOTPSource?.fieldName
        for (key, value) in source.customFields.sorted(by: { $0.key < $1.key })
        where isPlainCustomField(key) && key != sourceOTPField {
            guard customFields[key] != value else { continue }
            var name = key
            if customFields[name] != nil {
                name = "\(key) (\(source.title))"
                var suffix = 2
                while customFields[name] != nil {
                    name = "\(key) (\(source.title) \(suffix))"
                    suffix += 1
                }
            }
            customFields[name] = value
            if source.protectedStringKeys.contains(key) {
                protectedKeys.insert(name)
            }
            addedFieldNames.append(name)
        }
        if addedFieldNames.isEmpty == false {
            additions.append(.customFields(addedFieldNames))
        }

        if let passkey = source.passkeyPrivateKey, target.hasPasskey == false, source.hasPasskey {
            for key in PasskeyCredential.allFieldKeys {
                if let value = source.customFields[key] { customFields[key] = value }
            }
            customFields[PasskeyCredential.privateKeyPEMKey] = try passkey.decrypt(using: sessionKey)
            protectedKeys.formUnion(PasskeyCredential.protectedFieldKeys)
            additions.append(.passkey)
        }

        var totpConfig = try target.totpConfig.map { try draftTOTP(from: $0, otpURL: target.otpURL, sessionKey: sessionKey) }
        if totpConfig == nil, let sourceConfig = source.totpConfig {
            totpConfig = try draftTOTP(from: sourceConfig, otpURL: source.otpURL, sessionKey: sessionKey)
            // A KeeOTP-style source field does not come along, so the target
            // stores the code in the standard form instead.
            totpConfig?.keeOTPSource = nil
            additions.append(.verificationCode)
        }

        let newTags = source.tags.filter { tag in
            target.tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame } == false
        }
        if newTags.isEmpty == false {
            additions.append(.tags(newTags))
        }

        return Result(
            draft: EntryDraftPayload(
                title: target.title.isEmpty ? source.title : target.title,
                username: username,
                password: password,
                url: url,
                notes: notes,
                customFields: customFields,
                protectedCustomFieldKeys: protectedKeys,
                tags: target.tags + newTags,
                totpConfig: totpConfig
            ),
            additions: additions
        )
    }

    private static func draftTOTP(
        from config: TOTPConfig,
        otpURL: String?,
        sessionKey: SymmetricKey
    ) throws -> EntryDraftPayload.TOTPConfiguration {
        EntryDraftPayload.TOTPConfiguration(
            secret: try config.secret.decrypt(using: sessionKey),
            decodedSecret: try config.decodedSecret?.decryptData(using: sessionKey),
            keeOTPSource: config.keeOTPSource,
            period: config.period,
            digits: config.digits,
            algorithm: config.algorithm,
            otpauthURI: config.keeOTPSource == nil ? otpURL : nil
        )
    }

    private static func isPlainCustomField(_ key: String) -> Bool {
        PasskeyCredential.allFieldKeys.contains(key) == false
            && key.hasPrefix(additionalURLPrefix) == false
            && key.hasPrefix("TimeOtp-") == false
            && totpFieldNames.contains(key) == false
    }

    private static func normalizedURL(_ url: String) -> String {
        var value = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }
}
