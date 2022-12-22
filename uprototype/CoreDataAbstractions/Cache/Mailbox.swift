//
//  Mailbox.swift
//  uprototype
//
//  Created by Mark Xue on 11/17/22.
//

import CoreData

class Mailbox {
    let id: JMAPid
    var name: String
    var role: String?
    
    var managedObjectId : NSManagedObjectID?
    
    required init(stored: CDMailbox) throws {
        guard let storedId = stored.id_,
              let storedName = stored.name else{
            throw PersistenceError.expectedObjectMissing
        }
        id = storedId
        name = storedName
        role = stored.role
        
        managedObjectId = stored.objectID
    }
    
    required init(remote: JMAPMailbox) {
        id = remote.id
        name = remote.name
        role = remote.role
    }
    
    private init(id: JMAPid, name: String, role: String? = nil, managedObjectId: NSManagedObjectID? = nil) {
        self.id = id
        self.name = name
        self.role = role
        self.managedObjectId = managedObjectId
    }
}



extension Mailbox : AccountAbstractedObject {
    typealias RemoteType = JMAPMailbox
    typealias NSManagedType = CDMailbox
    
    static func findMananged(like remote: JMAPMailbox, in account: Account, context: NSManagedObjectContext) throws -> CDMailbox? {
        guard let accountObj = try account.managedObject(context: context) else {
            throw PersistenceError.expectedObjectMissing
        }
            let predicate = NSPredicate(format: "id_ == %@ AND account == %@", remote.id, accountObj)
        
        let request = CDMailbox.fetchRequest(predicate)
        let results = try context.fetch(request)
        if results.count > 1 {
            throw PersistenceError.duplicateUniqueObject
        }
        return results.first
    }
    
    
    
    func merge(_ remote:JMAPMailbox) {
        name = remote.name
        role = remote.role
    }
    
    func save() throws {
        let context = PersistenceController.shared.newCacheTaskContext()
        try context.performAndWait {
            let storedMailbox : CDMailbox
            if let managedObjectId {
                guard let mailbox = try context.existingObject(with: managedObjectId) as? CDMailbox else {
                    throw PersistenceError.expectedObjectMissing
                    
                }
                storedMailbox = mailbox
            }else{
                storedMailbox = CDMailbox(context: context)
            }
            
            storedMailbox.id_ = id
            storedMailbox.name = name
            storedMailbox.role = role
            
            try context.save()
            if managedObjectId == nil{
                managedObjectId = storedMailbox.objectID
            }
        }
    }
}

extension CDMailbox : AccountScoped {}

extension CDMailbox {
    static func fetchRequest(_ predicate: NSPredicate) -> NSFetchRequest<CDMailbox> {
        let request = NSFetchRequest<CDMailbox>(entityName: "CDMailbox")
        request.sortDescriptors = [NSSortDescriptor(key:"id_", ascending: true)]
        request.predicate = predicate
        return request
    }
        
    
    static func remove(ids: [JMAPid], from account: Account) throws {
        let context = PersistenceController.shared.newCacheTaskContext()
        try context.performAndWait {
            for id in ids{
                let predicate = NSPredicate(format: "id_ == %@ AND account.uid == %@", id, account.uid)
                let fetchRequest = CDMailbox.fetchRequest(predicate)
                let results = try context.fetch(fetchRequest)
                if results.count != 1 {
                    throw PersistenceError.expectedObjectMissing
                }
                context.delete(results[0])
            }
            try context.save()
            
        }
    }
}
