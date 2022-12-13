//
//  Identity.swift
//  uprototype
//
//  Created by Universal on 12/9/22.
//

import CoreData

class EmailIdentity {
    let id: JMAPid //= serverSetId in Core Data
    let email: String //immutable
    var name: String
    var initialized = false //has the bootstrap job been run on this identity yet. if nil, then false
    
    var managedObjectId : NSManagedObjectID? = nil
    
    required init(stored: CDIdentity) throws {
        guard let storedId = stored.serverSetId,
              let storedEmail = stored.email else{
            throw MailModelError.requiredFieldMissing
        }
        id = storedId
        email = storedEmail
        name = stored.name ?? ""
        managedObjectId = stored.objectID
    }
    
    required init(remote: JMAPIdentity) {
        id = remote.id
        email = remote.email
        name = remote.name
    }
}

extension EmailIdentity : CoreDataAbstraction {
    typealias RemoteType = JMAPIdentity
    typealias NSManagedType = CDIdentity
    
    static func findMananged(like remote: JMAPIdentity, in account: Account, context: NSManagedObjectContext) throws -> CDIdentity? {
        guard let accountObj = try account.managedObject(context: context) else {
            throw MailModelError.expectedObjectMissing
        }
        let predicate = NSPredicate(format: "serverSetId == %@ AND account == %@", remote.id, accountObj)
        
        let request = CDIdentity.fetchRequest(predicate)
        let results = try context.fetch(request)
        if results.count > 1 {
            throw MailModelError.duplicateUniqueObject
        }
        return results.first
    }

    func merge(_ remote:JMAPIdentity) throws {
        if email != remote.email {
            throw JMAPRemoteError.unexpectedError("immutable Identity email changed \(remote.email)")
        }
        name = remote.name
    }
    
    func save() throws {
        let context = PersistenceController.shared.newCacheTaskContext()
        try context.performAndWait {
            let storedIdentity: CDIdentity
            if let managedObjectId {
                guard let identity = try context.existingObject(with: managedObjectId) as? CDIdentity else{
                    throw MailModelError.expectedObjectMissing
                }
                storedIdentity = identity
            }else{
                storedIdentity = CDIdentity(context: context)
            }
            
            storedIdentity.serverSetId = id
            storedIdentity.email = email
            storedIdentity.name = name
            storedIdentity.initialized = initialized
            
            try context.save()
            if managedObjectId == nil {
                managedObjectId = storedIdentity.objectID
            }
        }
    }
}


extension CDIdentity : AccountScoped {}

extension CDIdentity {
    static func fetchRequest(_ predicate: NSPredicate) -> NSFetchRequest<CDIdentity> {
        let request = NSFetchRequest<CDIdentity>(entityName: "CDIdentity")
        request.sortDescriptors = [NSSortDescriptor(key:"serverSetId", ascending: true)]
        request.predicate = predicate
        return request
    }

    static func remove(ids: [JMAPid], from account: Account) throws {
        let context = PersistenceController.shared.newCacheTaskContext()
        try context.performAndWait {
            for id in ids{
                let predicate = NSPredicate(format: "serverSetId == %@ AND account.uid == %@", id, account.uid)
                let fetchRequest = CDIdentity.fetchRequest(predicate)
                let results = try context.fetch(fetchRequest)
                if results.count != 1 {
                    throw MailModelError.expectedObjectMissing
                }
                context.delete(results[0])
            }
            try context.save()
        }
    }
}
