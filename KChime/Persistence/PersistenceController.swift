import CoreData

final class PersistenceController {
    nonisolated(unsafe) static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "KChime")

        let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID)!
            .appendingPathComponent("KChime.sqlite")

        let description = inMemory
            ? NSPersistentStoreDescription()
            : NSPersistentStoreDescription(url: groupURL)

        description.setOption(
            FileProtectionType.completeUnlessOpen as NSObject,
            forKey: NSPersistentStoreFileProtectionKey
        )

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        description.cloudKitContainerOptions = inMemory
            ? nil
            : NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.kchime.app")

        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error {
                // In production, report to crash analytics rather than fatalError
                fatalError("CoreData load failed: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Nuke all local data (user-initiated)

    func deleteAllData() {
        let entities = container.managedObjectModel.entities
        for entity in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity.name ?? "")
            let delete = NSBatchDeleteRequest(fetchRequest: request)
            _ = try? container.viewContext.execute(delete)
        }
        try? container.viewContext.save()
    }

    // MARK: - Preview helper

    nonisolated(unsafe) static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext

        let contact = ContactEntity(context: ctx)
        contact.id = UUID()
        contact.displayName = "Mom"
        try? contact.setEncryptedNotes("Lives in Phoenix. Prefers short replies.")
        contact.createdAt = Date()
        contact.updatedAt = Date()

        let reply = SavedReplyEntity(context: ctx)
        reply.id = UUID()
        reply.text = "On my way! See you in 10."
        reply.createdAt = Date()

        try? ctx.save()
        return controller
    }()
}
