import SwiftUI

struct AutoFillPasskeyCreatorView: View {
    private struct AlertState: Identifiable {
        enum Kind {
            case warningAndCancel
            case error
        }

        let kind: Kind
        let message: String

        var id: String {
            "\(kind)-\(message)"
        }
    }

    /// What the Save To picker selects; `nil` is a new entry.
    private typealias Target = UUID?

    let context: CredentialProviderPasskeyCreatorContext
    let onSave: @Sendable (CredentialProviderPasskeyDestination) async -> CredentialProviderEntrySaveOutcome
    let onCancel: () -> Void

    @State private var title: String
    @State private var target: Target
    @State private var groupID: UUID
    @State private var isSaving = false
    @State private var inlineWarningMessage: String?
    @State private var alertState: AlertState?

    init(
        context: CredentialProviderPasskeyCreatorContext,
        onSave: @escaping @Sendable (CredentialProviderPasskeyDestination) async -> CredentialProviderEntrySaveOutcome,
        onCancel: @escaping () -> Void
    ) {
        self.context = context
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: context.initialTitle)
        // An entry already signed in with this user name is almost certainly
        // the login the passkey belongs to.
        let sameUserEntry = context.existingEntries.first {
            $0.username.caseInsensitiveCompare(context.userName) == .orderedSame
        }
        _target = State(initialValue: sameUserEntry?.id)
        _groupID = State(initialValue: context.defaultGroupID)
    }

    var body: some View {
        NavigationStack {
            #if os(macOS)
            VStack(spacing: 0) {
                AutoFillMacHeader {
                    HStack {
                        Text("New Passkey")
                            .font(.headline)
                        Spacer()
                    }
                }
                form
                AutoFillMacFooter {
                    cancelButton
                        .keyboardShortcut(.cancelAction)
                    saveButton
                        .keyboardShortcut(.defaultAction)
                }
            }
            #else
            form
            #endif
        }
        .alert(item: $alertState) { state in
            Alert(
                title: Text(state.kind == .warningAndCancel ? "Database Changed" : "Couldn't Save"),
                message: Text(state.message),
                dismissButton: .default(Text("OK")) {
                    if state.kind == .warningAndCancel {
                        onCancel()
                    }
                }
            )
        }
    }

    private var cancelButton: some View {
        Button("Cancel", action: onCancel)
            .disabled(isSaving)
            .accessibilityIdentifier("autofill-passkey-creator.cancel")
    }

    @ViewBuilder
    private var saveButton: some View {
        if isSaving {
            ProgressView()
        } else {
            Button("Save Passkey") {
                Task {
                    await save()
                }
            }
            .accessibilityIdentifier("autofill-passkey-creator.save")
        }
    }

    private var form: some View {
        Form {
            if let inlineWarningMessage {
                Section {
                    Text(inlineWarningMessage)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("autofill-passkey-creator.database-changed-warning")
                }
            }

            Section {
                LabeledContent("Website", value: context.relyingPartyIdentifier)
                    .accessibilityIdentifier("autofill-passkey-creator.relying-party")
                LabeledContent("Username", value: context.userName)
                    .accessibilityIdentifier("autofill-passkey-creator.username")
                LabeledContent("Database", value: context.databaseName)
                    .accessibilityIdentifier("autofill-passkey-creator.database")
            }

            if context.existingEntries.isEmpty == false {
                Section {
                    Picker("Save To", selection: $target) {
                        Text("New Entry").tag(Target.none)
                        ForEach(context.existingEntries) { entry in
                            Text(entryLabel(entry)).tag(Target.some(entry.id))
                        }
                    }
                    .accessibilityIdentifier("autofill-passkey-creator.target")
                } footer: {
                    if target != nil {
                        Text("Adds the passkey to this entry. Its current version is kept in the entry's history.")
                    }
                }
            }

            if target == nil {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        titleField
                            .accessibilityIdentifier("autofill-passkey-creator.title-field")
                    }
                    .padding(.vertical, 2)

                    if context.groups.count > 1 {
                        Picker("Group", selection: $groupID) {
                            ForEach(context.groups) { group in
                                Text(group.path).tag(group.id)
                            }
                        }
                        .accessibilityIdentifier("autofill-passkey-creator.group")
                    }
                }
            }
        }
        .macGroupedForm()
        .navigationTitle("New Passkey")
        .passkeyNavigationTitleStyle()
        .disabled(isSaving)
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                cancelButton
            }

            ToolbarItem(placement: .confirmationAction) {
                saveButton
            }
        }
        #endif
    }

    @ViewBuilder
    private var titleField: some View {
        #if os(iOS)
        TextField("Title", text: $title)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
        #else
        TextField("Title", text: $title)
        #endif
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        inlineWarningMessage = nil
        defer {
            isSaving = false
        }

        let destination: CredentialProviderPasskeyDestination = target.map { .existingEntry($0) }
            ?? .newEntry(title: title, groupID: groupID)
        switch await onSave(destination) {
        case .completed:
            break
        case .showWarningAndCancel(let message):
            inlineWarningMessage = message
            alertState = AlertState(kind: .warningAndCancel, message: message)
        case .showError(let message):
            alertState = AlertState(kind: .error, message: message)
        }
    }
}

private func entryLabel(_ entry: CredentialProviderPasskeyCreatorContext.ExistingEntry) -> String {
    entry.username.isEmpty ? entry.title : "\(entry.title) — \(entry.username)"
}

private extension View {
    @ViewBuilder
    func passkeyNavigationTitleStyle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
