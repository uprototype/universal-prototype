//
//  Persistence.swift
//  uprototype
//
//  Created by Mark Xue on 10/26/22.
//

import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.cacheContainer.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let cacheContainer: NSPersistentContainer
    let dataContainer: NSPersistentContainer
    
    private weak var debugState : DebugStateModel? = nil

    init(inMemory: Bool = false) {
        cacheContainer = NSPersistentContainer(name: "JMAPcache")
        if inMemory {
            cacheContainer.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        cacheContainer.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        cacheContainer.viewContext.automaticallyMergesChangesFromParent = true
        
        dataContainer = NSPersistentContainer(name: "UniversalRelationships")
        if inMemory {
            dataContainer.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        dataContainer.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        dataContainer.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func newCacheTaskContext() -> NSManagedObjectContext {
        // Create a private queue context.
        /// - Tag: newBackgroundContext
        let taskContext = cacheContainer.newBackgroundContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        // Set unused undoManager to nil for macOS (it is nil by default on iOS)
        // to reduce resource requirements.
        taskContext.undoManager = nil
        return taskContext
    }
    
    func newDataTaskContext() -> NSManagedObjectContext {
        // Create a private queue context.
        /// - Tag: newBackgroundContext
        let taskContext = dataContainer.newBackgroundContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        // Set unused undoManager to nil for macOS (it is nil by default on iOS)
        // to reduce resource requirements.
        taskContext.undoManager = nil
        return taskContext
    }
    
    func resetCache(observer: DebugStateModel?) {
        debugState = observer
        Task {
            let context = newCacheTaskContext()
            func delete(entityDescription: NSEntityDescription, progress: Double) throws {
                guard let entityName = entityDescription.name else {
                    return
                }
                
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                debugState?.updateReset(description: "Deleting \(entityName)", progress: progress)
                
                try context.execute(deleteRequest)
                try context.save()
            }
            
            do {
                let entities = cacheContainer.managedObjectModel.entities
                let total = entities.count - 1
                var progress = 0.0
                for entity in entities {
                    if entity.name != "CDCredential" {
                        try delete(entityDescription: entity, progress: progress)
                    }
                    progress += 1.0 / Double(total)
                }
                
                debugState?.updateReset(description: "Delete complete", progress: 1.0)
                
     
            }catch{
                print("Error resetting: \(error)")
            }
        }
    }
}
