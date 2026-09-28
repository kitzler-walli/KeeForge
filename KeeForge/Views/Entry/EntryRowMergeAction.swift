import SwiftUI

/// The Merge Into item every entry row's context menu offers, after Move to
/// Group. Shared so the wording, the gating, and the identifier cannot drift
/// per shell; like the move, it hands a `PendingMerge` back instead of
/// presenting, because each shell hosts the sheet where it hosts the others.
struct EntryRowMergeAction: View {
    let entryID: UUID
    let viewModel: DatabaseViewModel
    let onMerge: (PendingMerge) -> Void

    var body: some View {
        // Merging edits the kept entry and recycles this one, so it needs what
        // a move needs: a writable database and an entry outside the bin.
        if EntryRowMoveAction.isAvailable(entryID: entryID, viewModel: viewModel) {
            Button("Merge Into Another Entry…") {
                onMerge(PendingMerge(id: entryID))
            }
            .accessibilityIdentifier("entry-row.merge-context")
        }
    }
}
