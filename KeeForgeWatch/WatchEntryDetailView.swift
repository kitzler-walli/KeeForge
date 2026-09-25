import CryptoKit
import SwiftUI

struct WatchEntryDetailView: View {
    let entry: WatchVaultSnapshot.Entry

    @State private var isPasswordVisible = false

    var body: some View {
        List {
            if let totp = entry.totp {
                Section("Verification Code") {
                    TOTPCodeView(totp: totp)
                }
            }

            if entry.username.isEmpty == false {
                Section("Username") {
                    Text(entry.username)
                        .accessibilityIdentifier("watch.entry.username")
                }
            }

            if entry.password.isEmpty == false {
                Section("Password") {
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Text(isPasswordVisible ? entry.password : String(repeating: "•", count: 8))
                            .font(.body.monospaced())
                            .privacySensitive()
                    }
                    .accessibilityLabel(isPasswordVisible ? entry.password : String(localized: "Show Password"))
                    .accessibilityIdentifier("watch.entry.password")
                }
            }

            if entry.url.isEmpty == false {
                Section("Website") {
                    Text(entry.url)
                }
            }

            if entry.notes.isEmpty == false {
                Section("Notes") {
                    Text(entry.notes)
                }
            }
        }
        .navigationTitle(entry.title)
    }
}

/// Computes the code on the Watch from the stored secret, so it keeps working
/// with the iPhone out of reach.
private struct TOTPCodeView: View {
    let totp: WatchVaultSnapshot.TOTP

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = TOTPCode.secondsRemaining(period: totp.period, date: context.date)
            HStack {
                Text(Self.grouped(code(at: context.date)))
                    .font(.title2.monospacedDigit())
                    .privacySensitive()
                    .accessibilityIdentifier("watch.entry.totp")
                Spacer()
                Gauge(value: Double(remaining), in: 0...Double(max(1, totp.period))) {
                    Text(verbatim: "")
                } currentValueLabel: {
                    Text(verbatim: "\(remaining)")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .scaleEffect(0.6)
                .frame(width: 32, height: 32)
            }
        }
    }

    private func code(at date: Date) -> String {
        TOTPCode.generate(
            key: SymmetricKey(data: totp.secret),
            algorithm: totp.algorithm,
            digits: totp.digits,
            period: totp.period,
            date: date
        )
    }

    /// "123 456" / "1234 5678": split in half for reading off a small screen.
    private static func grouped(_ code: String) -> String {
        guard code.count >= 6 else { return code }
        let middle = code.index(code.startIndex, offsetBy: code.count / 2)
        return "\(code[..<middle]) \(code[middle...])"
    }
}
