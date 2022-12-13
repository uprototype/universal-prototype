//
//  Account.swift
//  uprototype
//
//  Created by Mark Xue on 11/21/22.
//

import CoreData
import Combine

/*
 Account objects are mapped as:
    JMAPAccount on server <-> Account <-> CDAccount in Core Data
 
 {object}State stores the last state from an {object}/verb method
 */

// since requests are made with credentials, and methods are usually account-scoped, keep map of credentials and accounts in memory in the mailmessagemodel
// Store the account<>mailbox association in core data for fetch purposes, but not needed to hold in memory
class Account {
    let uid: String
    var name: String
    //these are written after objects have been committed from that state
    var emailState: String?
    var identityState: String?
    var mailboxState: String?
    
    var managedObjectId : NSManagedObjectID?
    weak var credential : Credential?
    
    // MARK - Account as publisher of objects on the account
    // Values are JMAPSubject<JMAPObject>
    var typedSubjects = [JMAPObjectType:Any]()
    
    init(uid: String, name: String, emailState: String? = nil, identityState: String? = nil, mailboxState: String? = nil, managedObjectId: NSManagedObjectID? = nil, credential: Credential? = nil) {
        self.uid = uid
        self.name = name
        self.emailState = emailState
        self.identityState = identityState
        self.mailboxState = mailboxState
        self.managedObjectId = managedObjectId
        self.credential = credential
    }
}



extension Account {
    convenience init(stored: CDAccount) throws {
        guard let uid = stored.uid,
              let name = stored.name else {
            throw MailModelError.requiredFieldMissing
        }
        self.init(uid: uid,
                  name: name,
                  emailState: stored.emailState,
                  identityState: stored.identityState,
                  mailboxState: stored.mailboxState,
                  managedObjectId: stored.objectID)
    }
    
    func save(in context: NSManagedObjectContext) throws {
        guard let credentialObjId = credential?.managedObjectId,
              let storedCredential = try context.existingObject(with: credentialObjId) as? CDCredential else {
            throw MailModelError.expectedObjectMissing
        }
        let storedAccount = CDAccount(context: context)
        storedAccount.name = name
        storedAccount.uid = uid
        storedAccount.credential = storedCredential
        try context.save()
        managedObjectId = storedAccount.objectID
    }
    
    //expecting to be run within a perform block on the context
    func updateCD(in context: NSManagedObjectContext) throws {
        guard let objId = managedObjectId,
              let managedAccount = try context.existingObject(with: objId) as? CDAccount else {
            throw MailModelError.expectedObjectMissing
        }
        managedAccount.uid = uid
        managedAccount.name = name
        managedAccount.emailState = emailState
        managedAccount.identityState = identityState
        managedAccount.mailboxState = mailboxState
    }
    
    func updateCD() throws {
        let context = PersistenceController.shared.newCacheTaskContext()
        try context.performAndWait {
            try updateCD(in: context)
            try context.save()
        }
    }
    
    func update(from remote: JMAPAccount) {
        name = remote.name
    }
    
    func managedObject(context: NSManagedObjectContext) throws -> CDAccount? {
        guard let managedObjectId,
              let accountObj = try context.existingObject(with: managedObjectId) as? CDAccount else {
            throw MailModelError.expectedObjectMissing
        }
        return accountObj
        
    }
}

extension Account : Hashable {
    static func == (lhs: Account, rhs: Account) -> Bool {
        return lhs.uid == rhs.uid && lhs.credential?.uuid == rhs.credential?.uuid
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
        if let credential {
            hasher.combine(credential.uuid)
        }
    }
}

extension CDAccount {
    static func fetchRequest(_ predicate: NSPredicate) -> NSFetchRequest<CDAccount> {
        let request = NSFetchRequest<CDAccount>(entityName: "CDAccount")
        request.sortDescriptors = [NSSortDescriptor(key:"uid", ascending: true)]
        request.predicate = predicate
        return request
    }

    //deprecate
    static func fetch(uid: String, context: NSManagedObjectContext = PersistenceController.shared.newCacheTaskContext()) -> CDAccount? {
        let request = CDAccount.fetchRequest(NSPredicate(format: "uid == %@", uid) )
        do {
            let results = try context.fetch(request)
            if results.count == 1 {
                return results[0]
            }else{
                return nil
            }
        } catch {
            return nil
        }
    }
}

//Combine
/*
 Usage:
 fill in state
 start publishing objects
 */
class JMAPSubject<T> {
    var state: String? = nil
    var subject = PassthroughSubject<T, MailModelError>()
    var sink : AnyCancellable? = nil
}


