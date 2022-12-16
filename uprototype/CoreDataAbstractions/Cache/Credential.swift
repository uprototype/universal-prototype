//
//  Credential.swift
//  uprototype
//
//  Created by Mark Xue on 11/16/22.
//

import CoreData
import Combine
/*
    Kinds of objects in Credential lifetime:
    Credentials are a struct to represent the user-entered credentials - indexed by uuid, with password, session url, optional username
    CDCredential is the NSManagedObject used to persists the Credential and its relationship with Account objects
        The password is stored in keychain, Credential is responsible for uniting data from a CDCredential and the corresponding keychain entry
    Credentials can be used to obtain a JMAPSession object, which contains information about associated accounts
    These are joined in a SessionizedCredential which forms the basis for subsequent requests on a per-account basis
 
 
    Accounts are similarly mapped JMAPAccount <-> Account <-> CDAccount
 
 */

struct SessionizedCredential {
    let credential: Credential
    let session: JMAPSession
    
    var task : Task<(), Error>? = nil
    
    //performing account creation here because it only happens when we hydrate a credential with a JMAP session
    init(credential: Credential, session: JMAPSession) throws {
        self.credential = credential
        self.session = session
        self.credential.userName = session.raw.username
        try self.credential.save()
        try credential.mergeAccounts(from: session)
    }
}

extension SessionizedCredential {
    func fetchMailboxes() async throws  {
        for account in credential.accounts {
            if let mailboxState = account.mailboxState{
                try await mailboxChanges(for: account, state: mailboxState)
            }else{
                try await mailboxGet(for: account)
            }
        }
    }
    
    private func mailboxChanges(for account: Account, state: String) async throws {
        let requestData = try JMAPMailbox.ChangesCall(accountId: account.uid, sinceState: state).requestData()
        let responseData = try await session.call(data: requestData)
        let changesResponse = try JMAPMailbox.ChangesResponse(responseData: responseData,
                                                              accountId: account.uid,
                                                              sessionState: session.raw.state)
        
        //handle change object ids
        try CDMailbox.remove(ids: changesResponse.destroyed, from: account)
        
        
        let fetchList = Array( Set(changesResponse.created).union(changesResponse.updated) )
        if !fetchList.isEmpty {
            try await mailboxGet(for: account, ids: fetchList)
        }
        
        account.mailboxState = changesResponse.newState
        
        //recursively handle hasMoreChanges
        if changesResponse.hasMoreChanges  {
            try await mailboxChanges(for: account, state: changesResponse.newState)
        }
    }
    
    private func mailboxGet(for account: Account, ids:[JMAPid]? = nil) async throws {
        let requestData = try JMAPMailbox.GetCall(accountId: account.uid, ids: ids).requestData()
        let responseData = try await session.call(data: requestData)
        do{
            let mailboxResponse = try JMAPMailbox.GetResponse(responseData: responseData,
                                                              accountId: account.uid,
                                                              sessionState: session.raw.state)
            Mailbox.processObjects(state: mailboxResponse.state, account: account, objects: mailboxResponse.list)
            
        }catch MailModelError.sessionInvalid{
            await MailMessageModel.shared.invalidateSession(self)
        }
        
    }
    
    //MARK: Identities
    func fetchIdentities() async throws {
        for account in credential.accounts {
            try await identityGet(for: account)
//            if let identityState = account.identityState{
//                try await identityChanges(for: account, state: identityState)
//            }else{
//                try await identityGet(for: account)
//            }
        }
    }
    
    //not currently supported on server
    private func identityChanges(for account: Account, state: String) async throws {
        let requestData = try JMAPIdentity.ChangesCall(accountId: account.uid, sinceState: state).requestData()
        let responseData = try await session.call(data: requestData)
        let changesResponse = try JMAPMailbox.ChangesResponse(responseData: responseData, accountId: account.uid, sessionState: session.raw.state)

        try CDIdentity.remove(ids: changesResponse.destroyed, from:account)

        let fetchList = Array( Set ( changesResponse.created).union(changesResponse.updated) )
        if !fetchList.isEmpty {
            try await identityGet(for: account, ids: fetchList)
        }

        account.identityState = changesResponse.newState

        if changesResponse.hasMoreChanges {
            try await identityChanges(for: account, state: changesResponse.newState)
        }
    }
    
    private func identityGet(for account: Account, ids:[JMAPid]? = nil) async throws {
        let requestData = try JMAPIdentity.GetCall(accountId: account.uid, ids:ids).requestData()
        let responseData = try await session.call(data: requestData)
        do {
            let identityResponse = try JMAPIdentity.GetResponse(responseData: responseData, accountId: account.uid, sessionState: session.raw.state)
            EmailIdentity.processObjects(state: identityResponse.state, account: account, objects: identityResponse.list)
        }catch MailModelError.sessionInvalid {
            await MailMessageModel.shared.invalidateSession(self)
        }
    }
}

class Credential {
    let sessionURL: URL
    var userName: String? = nil
    let uuid: UUID
    var managedObjectId : NSManagedObjectID?
    //todo: private
    var password : String
    //don't let this be set except through functions that will persist relationship too
    private (set) var accounts = Set<Account>()
    
    //constructor accepts pre-session data
    //ensures all externally created objects have a corresponding managed object
    static func new(sessionURL: URL, uuid: UUID, password: String) throws -> Credential {
        let credential = Credential(sessionURL: sessionURL, uuid: uuid, password: password)
        try credential.savePassword()
        //fills in managedObjectID on completion
        try credential.save()
        return credential
    }
    
    // Credential -> CDCredential
    //Saves attributes back to the paired NSManaged object. runs through subordinate accounts and saves them too
    func save() throws {
        let context = PersistenceController.shared.newCacheTaskContext()
        try context.performAndWait {
            let storedCredential : CDCredential
            if let existingObjId = self.managedObjectId {
                guard let credential = try context.existingObject(with: existingObjId) as? CDCredential else {
                    throw PersistenceError.expectedObjectMissing
                }
                storedCredential = credential
            }else{
                storedCredential = CDCredential(context: context)
            }
            
            storedCredential.sessionURL = self.sessionURL
            storedCredential.userName = self.userName
            storedCredential.uuid = self.uuid
            
            for account in self.accounts {
                try account.updateCD(in: context)
            }
            try context.save()
            if managedObjectId == nil {
                managedObjectId = storedCredential.objectID
            }
        }
    }
    
    static func allCredentials() throws -> [Credential] {
        let context = PersistenceController.shared.newCacheTaskContext()
        return try context.performAndWait {
            let request = CDCredential.fetchRequest()
            return try context.fetch(request).compactMap{
                try Credential(stored: $0)
            }
            
        }
    }
    
    func mergeAccounts(from session: JMAPSession) throws {
        let context = PersistenceController.shared.newCacheTaskContext()
        try context.performAndWait {
            let remoteList = session.raw.accounts
            var insertList = remoteList
            try (accounts.forEach) { localAccount in
                if let remoteAccount = remoteList[localAccount.uid] {
                    //remove from queue
                    insertList[localAccount.uid] = nil
                    localAccount.update(from: remoteAccount)
                    //                    try mergeAccount(local: localAccount, remote: remoteAccount)
                }else{
                    //TODO: Merge strategy for orphaned mailboxes
                    //credential no longer grants access to this account, but keep the cd store referenced by any mailbox accounts
                    accounts.remove(localAccount)
                    localAccount.credential = nil
                }
            }
            
            try insertList.forEach{ (uid, remoteAccount) in
                try addRemoteAccount(remoteAccount, uid: uid, context: context)
            }
        }
    }
    
    // expects to be run in a context
    func addRemoteAccount(_ account:JMAPAccount, uid: JMAPid, context: NSManagedObjectContext) throws {
        let account = Account(uid: uid, name: account.name)
        account.credential = self
        try account.save(in: context)
        accounts.insert(account)
    }
    
    private init(sessionURL: URL, uuid: UUID, password: String, userName: String? = nil){
        self.sessionURL = sessionURL
        self.uuid = uuid
        self.password = password
        self.userName = userName
    }
    
    private convenience init(stored: CDCredential) throws {
        guard let storedSessionURL = stored.sessionURL,
              let storedUUID = stored.uuid else {
            throw PersistenceError.requiredAttributeMissing
        }
        
        guard let passwordString = KeychainInterface.readPasswordMaybe(service: storedSessionURL.absoluteString, account: storedUUID.uuidString) else {
            throw MailModelError.passwordMissing
        }
        
        
        self.init(sessionURL: storedSessionURL,
                  uuid: storedUUID,
                  password: passwordString,
                  userName: stored.userName)
        self.managedObjectId = stored.objectID
        
        try stored.accounts?.forEach { storedAccount in
            guard let storedAccount = storedAccount as? CDAccount else{
                throw PersistenceError.expectedObjectMissing
            }
            let account = try Account(stored: storedAccount)
            accounts.insert(account)
            account.credential = self
        }
        
    }
    
    private func savePassword() throws {
        try KeychainInterface.save(password: password, service: sessionURL.absoluteString, account: uuid.uuidString)
    }
    
}

extension CDCredential {
    static func fetchRequest(_ predicate: NSPredicate) -> NSFetchRequest<CDCredential> {
        let request = NSFetchRequest<CDCredential>(entityName: "CDCredential")
        request.sortDescriptors = [NSSortDescriptor(key:"uuid", ascending: true)]
        request.predicate = predicate
        return request
    }
    
    //should only be done in the context's fetch block
    static func fetch(uuid: UUID, context: NSManagedObjectContext) throws -> CDCredential {
        let predicate = NSPredicate(format: "uuid == %@", uuid as NSUUID)

        let request = CDCredential.fetchRequest(predicate)
        do {
            let results = try context.fetch(request)
            if results.count == 1 {
                return results[0]
            }else{
                throw PersistenceError.duplicateUniqueObject
            }
        } catch {
            throw PersistenceError.abstractObjectWithoutStoredCopy
        }
    }

    
    //deprecate
    func delete() {
        let thisFunction = "\(String(describing: self)).\(#function)"
        
        guard let uuid = uuid,
              let sessionURL = sessionURL else {
            print("\(thisFunction): tried to delete credential with null UUID")
            return
        }
        
        do {
            try KeychainInterface.deletePassword(service: sessionURL.absoluteString, account: uuid.uuidString )            
        }catch{
            print("\(thisFunction) delete password failed with \(error)")
        }
        managedObjectContext?.delete(self)
    }
    

}

