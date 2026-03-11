import SwiftUI
import CoreData

struct ContactsView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ContactEntity.displayName, ascending: true)],
        animation: .default
    )
    private var contacts: FetchedResults<ContactEntity>

    @State private var showAddContact = false
    @State private var searchText = ""
    @State private var contactToDelete: ContactEntity? = nil
    @State private var showDeleteConfirm = false

    private var filteredContacts: [ContactEntity] {
        let all = Array(contacts)
        if searchText.isEmpty { return all }
        return all.filter {
            ($0.displayName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if contacts.isEmpty {
                    ContentUnavailableView(
                        "No contact memory yet",
                        systemImage: "person.2",
                        description: Text("Opt in to remember context about specific contacts for smarter replies.")
                    )
                } else {
                    List {
                        ForEach(filteredContacts, id: \.objectID) { contact in
                            NavigationLink(destination: ContactDetailView(contact: contact)) {
                                ContactRow(contact: contact)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    contactToDelete = contact
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(
                        text: $searchText,
                        placement: .navigationBarDrawer(displayMode: contacts.count > 3 ? .always : .automatic),
                        prompt: "Search contacts"
                    )
                }
            }
            .navigationTitle("Contact Memory")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddContact = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddContact) {
                ContactEditView(contact: nil)
            }
            .confirmationDialog(
                "Delete contact?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let contact = contactToDelete {
                        context.delete(contact)
                        try? context.save()
                        ToastManager.shared.show("Contact deleted", type: .success)
                    }
                    contactToDelete = nil
                }
                Button("Cancel", role: .cancel) { contactToDelete = nil }
            } message: {
                Text("This will permanently remove \(contactToDelete?.displayName ?? "this contact") and their notes.")
            }
        }
    }
}

// MARK: - Row

struct ContactRow: View {
    let contact: ContactEntity

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(String(contact.displayName?.prefix(1) ?? "?"))
                    .font(.headline)
                    .foregroundStyle(.teal)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName ?? "Unknown")
                    .font(.headline)
                if let notes = contact.decryptedNotes(), !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Detail / Edit

struct ContactDetailView: View {
    let contact: ContactEntity

    var body: some View {
        ContactEditView(contact: contact)
    }
}

struct ContactEditView: View {
    let contact: ContactEntity?
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Mom, Coach Sarah", text: $name)
                }
                Section {
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("e.g. Lives in Austin, prefers formal tone, birthday is April 3")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $notes)
                            .frame(minHeight: 120)
                    }
                } header: {
                    Text("Notes (sent to AI, never stored on our server)")
                } footer: {
                    Text("Max 500 characters")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(contact == nil ? "New Contact" : "Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let contact {
                    name = contact.displayName ?? ""
                    notes = contact.decryptedNotes() ?? ""
                }
            }
        }
    }

    private func save() {
        let trimmedNotes = String(notes.prefix(500))
        let entity = contact ?? ContactEntity(context: context)
        entity.id = entity.id ?? UUID()
        entity.displayName = name.trimmingCharacters(in: .whitespaces)
        entity.updatedAt = Date()
        if entity.createdAt == nil { entity.createdAt = Date() }

        do {
            try entity.setEncryptedNotes(trimmedNotes)
            try context.save()
            dismiss()
        } catch {
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }
}
