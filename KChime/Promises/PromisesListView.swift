import SwiftUI
@preconcurrency import UserNotifications

// MARK: - Main list

struct PromisesListView: View {
    @StateObject private var store = PromisesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if store.upcoming.isEmpty && store.past.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Promises")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if store.permissionDenied {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Enable Notifications", systemImage: "bell.slash.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .sheet(item: $store.editing) { promise in
                EditPromiseSheet(promise: promise) { updated in
                    store.save(updated)
                }
                .presentationDetents([.medium])
            }
            .task { await store.checkPermission() }
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            if !store.upcoming.isEmpty {
                Section("Upcoming") {
                    ForEach(store.upcoming) { promise in
                        PromiseRow(promise: promise, onComplete: { store.complete(promise) })
                            .contentShape(Rectangle())
                            .onTapGesture { store.editing = promise }
                    }
                    .onDelete { indexSet in store.delete(from: store.upcoming, at: indexSet) }
                }
            }

            if !store.past.isEmpty {
                Section("Past") {
                    ForEach(store.past) { promise in
                        PromiseRow(promise: promise, onComplete: { store.complete(promise) })
                            .contentShape(Rectangle())
                            .onTapGesture { store.editing = promise }
                    }
                    .onDelete { indexSet in store.delete(from: store.past, at: indexSet) }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.badge")
                .font(.system(size: 48))
                .foregroundStyle(Color.teal.opacity(0.5))
            Text("No Promises Yet")
                .font(.headline)
            Text("When you insert a reply containing a commitment\n(\"I'll send it tonight\"), KChime will offer to set a reminder.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct PromiseRow: View {
    let promise: KChimePromise
    let onComplete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Completion circle
            Button(action: onComplete) {
                Image(systemName: promise.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(promise.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(promise.text)
                    .font(.subheadline)
                    .foregroundStyle(promise.isCompleted ? .secondary : .primary)
                    .strikethrough(promise.isCompleted)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: promise.isCompleted ? "checkmark" : dateIcon(for: promise.reminderDate))
                        .font(.caption2)
                        .foregroundStyle(dateColor(for: promise.reminderDate, completed: promise.isCompleted))
                    Text(relativeDateLabel(for: promise.reminderDate, completed: promise.isCompleted))
                        .font(.caption)
                        .foregroundStyle(dateColor(for: promise.reminderDate, completed: promise.isCompleted))
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func dateIcon(for date: Date) -> String {
        date < Date() ? "clock.badge.exclamationmark" : "bell"
    }

    private func dateColor(for date: Date, completed: Bool) -> Color {
        if completed { return .secondary }
        return date < Date() ? .orange : .secondary
    }

    private func relativeDateLabel(for date: Date, completed: Bool) -> String {
        if completed { return "Done" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Edit sheet

private struct EditPromiseSheet: View {
    @Environment(\.dismiss) private var dismiss
    var promise: KChimePromise
    var onSave: (KChimePromise) -> Void

    @State private var reminderDate: Date

    init(promise: KChimePromise, onSave: @escaping (KChimePromise) -> Void) {
        self.promise = promise
        self.onSave = onSave
        _reminderDate = State(initialValue: promise.reminderDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Promise") {
                    Text(promise.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Reminder Time") {
                    DatePicker(
                        "Remind me at",
                        selection: $reminderDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                }
            }
            .navigationTitle("Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = promise
                        updated.reminderDate = reminderDate
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(reminderDate < Date().addingTimeInterval(-60))
                }
            }
        }
    }
}

// MARK: - View model

@MainActor
private final class PromisesViewModel: ObservableObject {
    @Published var upcoming: [KChimePromise] = []
    @Published var past: [KChimePromise] = []
    @Published var editing: KChimePromise?
    @Published var permissionDenied = false

    nonisolated init() {
        let store = PromiseStore.shared
        _upcoming = Published(initialValue: store.upcoming)
        _past = Published(initialValue: store.past)
    }

    func reload() {
        upcoming = PromiseStore.shared.upcoming
        past     = PromiseStore.shared.past
    }

    func complete(_ promise: KChimePromise) {
        PromiseStore.shared.markCompleted(id: promise.id)
        PromiseNotificationScheduler.cancel(notificationID: promise.notificationID)
        reload()
    }

    func save(_ promise: KChimePromise) {
        PromiseStore.shared.update(promise)
        PromiseNotificationScheduler.reschedule(promise)
        reload()
    }

    func delete(from section: [KChimePromise], at offsets: IndexSet) {
        for index in offsets {
            guard index < section.count else { continue }
            let promise = section[index]
            PromiseStore.shared.delete(id: promise.id)
            PromiseNotificationScheduler.cancel(notificationID: promise.notificationID)
        }
        reload()
    }

    func checkPermission() async {
        let status = await PromiseNotificationScheduler.authorizationStatus()
        permissionDenied = status == .denied

        // Request if not yet determined (first time opening Promises tab)
        if status == .notDetermined {
            await PromiseNotificationScheduler.requestPermission()
            permissionDenied = await PromiseNotificationScheduler.authorizationStatus() == .denied
        }
    }
}
