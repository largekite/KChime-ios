import SwiftUI
import CoreData

struct SavedRepliesView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SavedReplyEntity.createdAt, ascending: false)],
        animation: .default
    )
    private var replies: FetchedResults<SavedReplyEntity>

    @State private var searchText = ""

    private var filtered: [SavedReplyEntity] {
        guard !searchText.isEmpty else { return Array(replies) }
        return replies.filter {
            ($0.text ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if replies.isEmpty {
                    ContentUnavailableView(
                        "No saved replies yet",
                        systemImage: "bookmark",
                        description: Text("Star a suggestion in the keyboard or share extension to save it here.")
                    )
                } else {
                    List {
                        ForEach(filtered, id: \.objectID) { reply in
                            SavedReplyRow(reply: reply)
                        }
                        .onDelete(perform: deleteReplies)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Saved Replies")
            .searchable(text: $searchText, prompt: "Search saved replies")
            .toolbar {
                if !replies.isEmpty {
                    EditButton()
                }
            }
        }
    }

    private func deleteReplies(at offsets: IndexSet) {
        let snapshot = filtered
        let toDelete = offsets.compactMap { idx -> SavedReplyEntity? in
            idx < snapshot.count ? snapshot[idx] : nil
        }
        for entity in toDelete {
            context.delete(entity)
        }
        try? context.save()
    }
}

struct SavedReplyRow: View {
    let reply: SavedReplyEntity
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(reply.text ?? "")
                    .font(.body)
                    .lineLimit(3)
                if let date = reply.createdAt {
                    Text(date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: copyText) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.callout)
                    .foregroundStyle(copied ? .green : .secondary)
                    .animation(.easeInOut, value: copied)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func copyText() {
        UIPasteboard.general.string = reply.text
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}
