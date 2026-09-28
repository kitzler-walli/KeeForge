import SwiftUI

extension View {
    /// Hosts the merge sheet for an entry-row context-menu request.
    func entryMergeSheet(item: Binding<PendingMerge?>, viewModel: DatabaseViewModel) -> some View {
        sheet(item: item) { pending in
            EntryMergeSheet(sourceEntryID: pending.id, viewModel: viewModel) { _ in }
        }
    }
}

/// "Merge Into…" for one entry: pick the entry to keep — searchable, listed
/// under its folder path — then confirm a preview of what it gains. The
/// target keeps its own values; the merged entry goes to the recycle bin.
///
/// Both steps live in one view with in-content buttons rather than a pushed
/// screen: a push inside a macOS sheet loses the sheet's toolbar.
struct EntryMergeSheet: View {
    let sourceEntryID: UUID
    let viewModel: DatabaseViewModel
    /// Called after a successful merge, with the entry that was kept.
    let onMerged: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var targetID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let targetID {
                    preview(targetID: targetID)
                } else {
                    picker
                }
                Divider()
                buttonBar
            }
            .navigationTitle("Merge Into Another Entry")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .macSheetFrame(minWidth: 520, minHeight: 520)
        .alert(
            "Couldn't Merge",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Step 1: pick the entry to keep

    private var picker: some View {
        VStack(spacing: 0) {
            TextField("Search Entries", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .padding()
                .accessibilityIdentifier("entry-merge.search")

            let sections = filteredSections
            if sections.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(sections, id: \.path) { section in
                        Section(section.path) {
                            ForEach(section.options) { option in
                                Button {
                                    targetID = option.id
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.title.isEmpty ? String(localized: "Untitled") : option.title)
                                        if option.username.isEmpty == false {
                                            Text(option.username)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .macHoverHighlight()
                                .accessibilityIdentifier("entry-merge.target.\(option.id.uuidString)")
                            }
                        }
                    }
                }
            }
        }
    }

    private var filteredSections: [(path: String, options: [DatabaseViewModel.MergeTargetOption])] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = viewModel.mergeTargetOptions(forEntryID: sourceEntryID).filter { option in
            query.isEmpty
                || option.title.localizedCaseInsensitiveContains(query)
                || option.username.localizedCaseInsensitiveContains(query)
                || option.groupPath.localizedCaseInsensitiveContains(query)
        }
        var sections: [(path: String, options: [DatabaseViewModel.MergeTargetOption])] = []
        for option in options {
            if sections.last?.path == option.groupPath {
                sections[sections.count - 1].options.append(option)
            } else {
                sections.append((option.groupPath, [option]))
            }
        }
        return sections
    }

    // MARK: - Step 2: preview

    @ViewBuilder
    private func preview(targetID: UUID) -> some View {
        let source = viewModel.entry(withID: sourceEntryID)
        let target = viewModel.entry(withID: targetID)
        Form {
            Section {
                LabeledContent("Merge", value: source?.title ?? "")
                LabeledContent("Into", value: target?.title ?? "")
                    .accessibilityIdentifier("entry-merge.preview.target")
            }

            switch previewResult(targetID: targetID) {
            case .success(let result):
                Section {
                    if result.additions.isEmpty {
                        Text("\(target?.title ?? "") already has everything this entry holds.")
                    } else {
                        ForEach(Array(result.additions.enumerated()), id: \.offset) { _, addition in
                            Label(description(of: addition), systemImage: "plus.circle")
                        }
                    }
                } header: {
                    Text("\(target?.title ?? "") Gains")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("It keeps its own title, user name, password, and website. Its current version is kept in its history.")
                        Text("“\(source?.title ?? "")” moves to the Recycle Bin.")
                        if source?.attachments.isEmpty == false {
                            Text("Attachments are not merged; they stay with the entry in the Recycle Bin.")
                        }
                    }
                }
            case .failure(let message):
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("entry-merge.preview.blocked")
                }
            }
        }
        .macGroupedForm()
    }

    private enum PreviewResult {
        case success(EntryMerger.Result)
        case failure(String)
    }

    private func previewResult(targetID: UUID) -> PreviewResult {
        do {
            return .success(try viewModel.mergePreview(merging: sourceEntryID, into: targetID))
        } catch EntryMerger.Failure.bothHavePasskeys {
            return .failure(String(localized: "Both entries have a passkey, and an entry can hold only one. Remove one of the passkeys first."))
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private func description(of addition: EntryMerger.Addition) -> String {
        switch addition {
        case .username: String(localized: "Username")
        case .password: String(localized: "Password")
        case .notes: String(localized: "Notes")
        case .urls(let count): String(localized: "Websites: \(count)")
        case .customFields(let names): String(localized: "Fields: \(names.joined(separator: ", "))")
        case .passkey: String(localized: "Passkey")
        case .verificationCode: String(localized: "Verification code")
        case .tags(let tags): String(localized: "Tags: \(tags.joined(separator: ", "))")
        }
    }

    // MARK: - Buttons

    private var buttonBar: some View {
        HStack {
            if targetID != nil {
                Button("Back") {
                    targetID = nil
                }
                .accessibilityIdentifier("entry-merge.back")
            }
            Spacer()
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("entry-merge.cancel")
            if let targetID {
                Button("Merge") {
                    merge(into: targetID)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(canMerge(into: targetID) == false)
                .accessibilityIdentifier("entry-merge.confirm")
            }
        }
        .padding()
    }

    private func canMerge(into targetID: UUID) -> Bool {
        if case .success = previewResult(targetID: targetID) { return true }
        return false
    }

    private func merge(into targetID: UUID) {
        do {
            try viewModel.mergeEntry(sourceEntryID, into: targetID)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        Task { await viewModel.saveHandlingError() }
        dismiss()
        onMerged(targetID)
    }
}
