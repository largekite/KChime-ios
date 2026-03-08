import SwiftUI

/// Shown below the tone chips after a suggestion is tapped.
/// Lets the user opt a contact into memory without leaving the keyboard.
struct MemoryOptInBanner: View {
    @Binding var isVisible: Bool
    let onYes: () -> Void

    var body: some View {
        if isVisible {
            HStack(spacing: 10) {
                Image(systemName: "brain")
                    .font(.caption)
                    .foregroundStyle(.teal)

                Text("Remember context for next time?")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Button("Yes") {
                    isVisible = false
                    onYes()
                }
                .font(.caption.bold())
                .foregroundStyle(.teal)

                Button("No") { isVisible = false }
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.teal.opacity(0.08))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// Bottom sheet for adding a contact note from inside the keyboard.
/// Saves to App Group UserDefaults; the main app merges into CoreData on next open.
struct QuickContactNoteSheet: View {
    @Binding var isPresented: Bool
    @State private var contactName = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact name") {
                    TextField("e.g. Mom, Coach Sarah", text: $contactName)
                }
                Section {
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("e.g. Prefers short replies, birthday April 3…")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                    }
                } header: {
                    Text("Notes (encrypted on device)")
                }
            }
            .navigationTitle("Remember Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(contactName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID)!
        var pending = defaults.array(forKey: "kchime_pending_contacts") as? [[String: String]] ?? []
        pending.append([
            "name": contactName.trimmingCharacters(in: .whitespaces),
            "notes": String(notes.prefix(500)),
        ])
        defaults.set(pending, forKey: "kchime_pending_contacts")
        isPresented = false
    }
}
