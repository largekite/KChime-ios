@preconcurrency import CoreData

final class PersistenceController {
    nonisolated(unsafe) static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "KChime")

        guard let baseURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("[PersistenceController] No writable directory available for CoreData store")
        }
        let groupURL = baseURL.appendingPathComponent("KChime.sqlite")

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

        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error {
                // Log error but do not crash in production
                print("[PersistenceController] CoreData load failed: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    // MARK: - Nuke all local data (user-initiated)

    func deleteAllData() {
        let context = container.viewContext
        let entities = container.managedObjectModel.entities
        for entity in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity.name ?? "")
            let delete = NSBatchDeleteRequest(fetchRequest: request)
            delete.resultType = .resultTypeObjectIDs
            if let result = try? context.execute(delete) as? NSBatchDeleteResult,
               let objectIDs = result.result as? [NSManagedObjectID] {
                let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
            }
        }
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
