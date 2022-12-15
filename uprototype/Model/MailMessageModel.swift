//
//  MailMessageModel.swift
//  uprototype
//
//  Created by Mark Xue on 11/21/22.
//


import Foundation
import Combine
//deprecate
//import CoreData

/*
 Model for fetching mail state (messages, structure) from a JMAP[+ other protocols] server, backed by core data layer that caches the server's state.
 
 Exposes
    - set of relationships (first, just sender email addresses)
        (conversation view)
    - set of messages from the relationship
        (conversation detail)
 
 
 Utility functions:
    For prototype debug purposes
        - list accounts
        - list mailboxes
        - list messages
        - list senders
 
 */

enum MailModelError : Error {
    case passwordMissing
    case duplicateCredential
    case expectedObjectMissing
    case sessionInvalid
}

actor MailMessageModel {
    static let shared = MailMessageModel()
    
    private(set) var sessions = [UUID:SessionizedCredential]()
    private weak var debugState : DebugStateModel? = nil
    
    //Combine - publish values for identities and relationships for the Relationship Model to consume
    var identitySubject = PassthroughSubject<EmailIdentityValue, Never>()
    var relationshipSubject = PassthroughSubject<EmailRelationshipValue, Never>()

    init() {
        Task{
            await RelationshipModel.shared.connect(to: self)
        }
        // TODO: -
//        Commenting out fetch on boot and making it manual during development of bootstrap code
        //
//        fetch()
    }
    
    func fetch(observer: DebugStateModel? = nil){
        let thisFunction = "\(String(describing: self)).\(#function)"
        
        self.debugState = observer
        self.debugState?.updateFetch(description: "started fetch", progress: 0.0)

        //get sessions for the credentials that I have
        Task {
            do {
                try await fetchSessions()
                //get changes to mailboxes
            }catch{
                print("\(thisFunction): Error in refetch \(error)")
            }
        }
    }
    
    /*
     token
     -> save in keychain
     -> save in core data
     -> (await) fetch from server
        -> update core data with results
     
     */
    
    func addJMAPCredential (token: String) async {
        let thisFunction = "\(String(describing: self)).\(#function)"
        
        // TODO: - hardcoded; will be an additional parameter if Exists picker
        guard let sessionURL = URL(string: JMAPSession.Constants.fastmailResourceURL) else {
            return
        }
        
        let uuid = UUID()
        
        do {
            let credential = try Credential.new(sessionURL: sessionURL, uuid:uuid, password: token)
            try await fetch(credential)
        }catch (KeychainInterface.KeychainError.duplicateItem){
            //should not run into duplicate, if so, recurse with fresh UUID
            await addJMAPCredential(token: token)
            print("\(thisFunction) unexpected duplicate UUID on adding account")
        }catch{
            print("\(thisFunction) error saving account token: \(error)")
        }
    }
    
    //TODO: change view to act on abstract layer
    func delete(credential: CDCredential) {
        guard let uuid = credential.uuid else {
            return
        }
        Task.detached {
            if let sessionObj = await self.sessions[uuid]{
                await self.invalidateSession(sessionObj)
                sessionObj.task?.cancel()
            }
        }
        credential.delete()
        
    }
    
    // MARK: - Implementation
    
    //main task on model boot
    //spins off a task for each session
    private func fetchSessions () async throws {
        let credentials = try Credential.allCredentials()
        
        guard !credentials.isEmpty else {
            debugState?.updateFetch(description: "No credentials to fetch", progress: 1.0)
            return
        }
        // TODO: only initializing first account before we handle multiple local identities
        for credential in credentials[0...0] {
            try await fetch(credential)
        }
    }

    
    /*
     Main function to update accounts when added, and on boot
     */
    private func fetch(_ credential:Credential) async throws {
        debugState?.updateFetch(description: "fetching Sessions", progress: 0.1)
        let session = try await fetchSession(credential: credential)
        var sessionObj = try SessionizedCredential(credential: credential, session: session)
        self.sessions[credential.uuid] = sessionObj
        sessionObj.task = Task {
            try await updatedSession(sessionObj)
        }
        
    }
    
    private func updatedSession(_ sessCredential: SessionizedCredential) async throws {
        debugState?.updateFetch(description: "fetching Mailboxes", progress: 0.3)
        try await sessCredential.fetchMailboxes()
        
        debugState?.updateFetch(description: "fetching Identities", progress: 0.4)
        try await sessCredential.fetchIdentities()
        //            try await indexedSession.syncIdentities()
        //
        debugState?.updateFetch(description: "fetching Emails", progress: 0.6)
        //            try await indexedSession.fetchSendThreads()
        //Fetch Emails
        //            try await fetchEmails(uuid: uuid, session: session)
        //
        debugState?.updateFetch(description: "fetch complete", progress: 1.0)

    }
    
    // MARK: - Implementation - Emails
    
    
    /*
     Prototype strategy v.2:
     Core Data as cache of emails in working set
     Working Set definition:
        - Identities: get for identities
            - TODO, offer user to add identities not present now, but in sent mailbox (e.g. imported)
        - Recipients: to, from or bcc on mail where i \in identities was the sender
        - for prototyping, limit to past year
     Batch fetch using query (of this subset) until initialized
     Then request changes each boot to all email and locally filter
     
     Initialization (optimized for working subset)
        - Fetch Session -> Accounts -> Mailboxes -> Identities
        - For identity in identities
            - create query for mail where to is identity
            - fetch id's and email objects in batches
        - when complete, mark email state in account object's email state
     
     Changes (optimize for completeness going forward)
        - ask for changes
        - download
     
     If new identity is discovered, run initialization for that identity.
     
     
     
     
     - get mailbox id's for a working set
     - Email/query for id's of the messages
     - Email/get those messages
     
     */
//    private func fetchEmails(uuid: UUID, session:JMAPSession) async throws {
//        //TODO: use a change request if the account's emailstate is occupied
//
//        let mailboxes = try await CDMailbox.mailboxes(for: .sent)
//        let parameters = mailboxes.compactMap{ mailbox in
//            if let mailboxId = mailbox.id_, let accountId = mailbox.account?.uid {
//                return (mailboxId, accountId)
//            }
//            return nil
//        }
//        
//        //mailboxId -> email IDs -thread query -> email id -> email obj
//        
//        try await withThrowingTaskGroup(of: Void.self) { group in
//            for (mailboxId, accountId) in parameters {
//                group.addTask {
//                    
//                    //-thread query -> email id -> email obj
//                    guard let threadIds = try await session.threadIds(in: mailboxId, accountId: accountId) else {
//                        return
//                    }
//                    while case let batch = threadIds.dropLast(JMAPSession.Constants.EmailBatchSize),
//                          !batch.isEmpty {
//                        try await Email.fetchEmails(ids: Array(batch), accountId: accountId, session: session)
//                    }
//                    try await Email.fetchEmails(ids: threadIds, accountId: accountId, session: session)
//                  
////                    print(threadIds)
//                }
//            }
//            try await group.waitForAll()
//            try mailboxes.first?.managedObjectContext?.save()
//        }
//    }
    
//    private func continue
    
    // MARK: - Network call wrappers (to JMAPFetcher)
    
    private func fetchSession(credential: Credential) async throws -> JMAPSession {
        return try await JMAPSession.fetch(token: credential.password, sessionURL: credential.sessionURL)

    }
    
    // MARK: - Exceptional Flow
    func invalidateSession(_ sessCredential: SessionizedCredential) {
        sessCredential.task?.cancel()
        let credential = sessCredential.credential
        let uuid = credential.uuid
        self.sessions[uuid] = nil
        Task.detached{
            try await self.fetch(credential)
        }
    }
    
    func resetCache() {
        sessions = [UUID:SessionizedCredential]()
    }
}
