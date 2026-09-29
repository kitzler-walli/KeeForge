import SwiftUI

/// The tip jar, shown only in an App Store build: a notarized direct-download
/// build has no receipt to purchase against, so StoreKit there would fail
/// rather than charge anyone.
struct SupportKeeForgeSection: View {
    var body: some View {
        #if !KEEFORGE_DIRECT_DOWNLOAD
        TipJarView()
        #endif
    }
}
