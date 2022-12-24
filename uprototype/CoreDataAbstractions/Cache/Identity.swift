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
    private (set) var accountId : JMAPid
    var initialized = false //has the bootstrap job been run on this identity yet. if nil, then false
    
    var managedObjectId : NSManagedObjectID? = nil
    
    required init(stored: CDIdentity) throws {
        guard let storedId = stored.serverSetId,
              let storedEmail = stored.email,
              let accountId = stored.account?.uid else{
            throw PersistenceError.requiredAttributeMissing
        }
        id = storedId
        email = storedEmail
        name = stored.name ?? ""
        initialized = stored.initialized
        self.accountId = accountId
        managedObjectId = stored.objectID
    }
    
    required init(remote: JMAPIdentity, accountId: String ) {
        id = remote.id
        email = remote.email
        name = remote.name
        self.accountId = accountId
    }
}

//for passing to relationshipModel
struct EmailIdentityValue {
    let email: String
    var name: String? //flatten "" to nil
}

struct EmailRelationshipValue {
    //sender name and identity
    //recipients
}

extension EmailIdentity : AccountAbstractedObject {
    typealias InputType = JMAPIdentity
    typealias NSManagedType = CDIdentity
    
    static func findMananged(like remote: JMAPIdentity, in account: Account, context: NSManagedObjectContext) throws -> CDIdentity? {
        guard let accountObj = try account.managedObject(context: context) else {
            throw PersistenceError.expectedObjectMissing
        }
        let predicate = NSPredicate(format: "serverSetId == %@ AND account == %@", remote.id, accountObj)
        
        let request = CDIdentity.fetchRequest(predicate)
        let results = try context.fetch(request)
        if results.count > 1 {
            throw PersistenceError.duplicateUniqueObject
        }
        return results.first
    }

    func merge(_ remote:JMAPIdentity) throws {
        if email != remote.email {
            throw JMAPRemoteError.unexpectedError("immutable Identity email changed \(remote.email)")
        }
        name = remote.name
        sendIdentityValue()
    }
    
    func save() throws {
        let context = PersistenceController.shared.newCacheTaskContext()
        try context.performAndWait {
            let storedIdentity: CDIdentity
            if let managedObjectId {
                guard let identity = try context.existingObject(with: managedObjectId) as? CDIdentity else{
                    throw PersistenceError.expectedObjectMissing
                }
                storedIdentity = identity
            }else{
                storedIdentity = CDIdentity(context: context)
            }
            
            storedIdentity.serverSetId = id
            storedIdentity.email = email
            storedIdentity.name = name
            
            try context.save()
            if managedObjectId == nil {
                managedObjectId = storedIdentity.objectID
            }
            sendIdentityValue()
        }
        
    }
    
    private func sendIdentityValue() {
        Task{
            let identityValue = EmailIdentityValue(email: email, name: name)
            await MailMessageModel.shared.identitySubject.send((identityValue, accountId))
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
                    throw PersistenceError.expectedObjectMissing
                }
                context.delete(results[0])
            }
            try context.save()
        }
    }
}
