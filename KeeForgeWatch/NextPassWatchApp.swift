import SwiftUI

@main
struct NextPassWatchApp: App {
    private let store: WatchVaultStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = WatchVaultStore()
        store.activate()
        self.store = store
    }

    var body: some Scene {
        WindowGroup {
            VaultListView(store: store)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .background {
                        store.unload()
                    } else {
                        store.load()
                    }
                }
        }
        // Lets watchOS wake the app for transfers that arrive while it is not
        // running, so entries are stored before the app is next opened.
        .backgroundTask(.watchConnectivity) {
            await store.receivePendingContent()
        }
    }
}
