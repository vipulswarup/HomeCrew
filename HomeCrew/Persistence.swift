//
//  Persistence.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 07/03/25.
//

import CoreData
import os.log

struct PersistenceController {
    static let shared = PersistenceController()
    
    // Logger for Core Data errors
    private static let logger = Logger(subsystem: "com.homecrew.persistence", category: "CoreData")

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Log the error instead of crashing
            let nsError = error as NSError
            logger.error("Failed to save preview data: \(nsError.localizedDescription)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "HomeCrew")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Log the error and provide recovery options instead of crashing
                Self.logger.error("Core Data store failed to load: \(error.localizedDescription)")
                
                // Attempt to recover by deleting the store and recreating it
                if let storeURL = storeDescription.url {
                    do {
                        try FileManager.default.removeItem(at: storeURL)
                        Self.logger.info("Removed corrupted Core Data store, will recreate on next launch")
                    } catch {
                        Self.logger.error("Failed to remove corrupted store: \(error.localizedDescription)")
                    }
                }
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
