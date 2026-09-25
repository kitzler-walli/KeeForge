import SwiftUI

struct VaultListView: View {
    let store: WatchVaultStore

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("NextPass")
                .navigationDestination(for: WatchVaultSnapshot.Entry.self) { entry in
                    WatchEntryDetailView(entry: entry)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.availability == .needsPasscode {
            ContentUnavailableView {
                Label("Passcode Required", systemImage: "lock")
            } description: {
                Text("Set a passcode on this Apple Watch to keep NextPass entries on it.")
            }
        } else if store.snapshots.isEmpty {
            ContentUnavailableView {
                Label("No Entries", systemImage: "applewatch")
            } description: {
                Text("On your iPhone, tag entries “Apple Watch” in NextPass and open the database. They stay available here without your iPhone.")
            }
        } else {
            List {
                ForEach(store.snapshots, id: \.databaseID) { snapshot in
                    Section {
                        ForEach(snapshot.entries) { entry in
                            NavigationLink(value: entry) {
                                EntryRow(entry: entry)
                            }
                            .accessibilityIdentifier("watch.entry.row")
                        }
                    } header: {
                        if store.snapshots.count > 1 {
                            Text(snapshot.databaseName)
                        }
                    }
                }
            }
        }
    }
}

private struct EntryRow: View {
    let entry: WatchVaultSnapshot.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title.isEmpty ? String(localized: "Untitled") : entry.title)
                .lineLimit(2)
            if entry.username.isEmpty == false {
                Text(entry.username)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
