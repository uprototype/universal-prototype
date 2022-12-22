//
//  JMAPSession+Methods.swift
//  uprototype
//
//  Created by Universal on 12/9/22.
//

import Foundation

//unite the remote data (JMAPSession) with the local index for persistence in Core Data and Keychain
struct IndexedSession {
    let id: UUID
    let session: JMAPSession
}

extension IndexedSession {
//        
//    func syncIdentities() async throws {
//        let context = PersistenceController.shared.newCacheTaskContext()
//        for accountUid in session.raw.accounts.keys {
//            guard let account = CDAccount.fetch(uid: accountUid, context: context) else {
//                throw PersistenceError.expectedObjectMissing
//            }
//            try await self.syncIdentities(account: account)
//        }
//        try context.save()
//    }
//

    
    // MARK: - Implementation - Identities
//
//    private func syncIdentities(account: CDAccount) async throws {
//        guard let accountId = account.uid else {
//            throw PersistenceError.requiredAttributeMissing
//        }
//
//        if let localIdentityState = account.identityState {
//            print("Local identity\(localIdentityState)")
//            let requestData = try JMAPIdentity.ChangesCall(accountId: accountId, sinceState: localIdentityState).requestData()
//            let responseData = try await session.call(data: requestData)
//
//            let changesResponse = try JMAPMailbox.ChangesResponse(responseData: responseData,
//                                                                  accountId: accountId,
//                                                                  sessionState: session.raw.state)
//
//            try removeIdentities(ids: changesResponse.destroyed, from: account)
//
//            let fetchList = Array(Set(changesResponse.created).union(changesResponse.updated))
//            let fetchState = try await fetchIdentities(account: account, ids: fetchList)
//
//            account.identityState = changesResponse.newState
//
//            if changesResponse.hasMoreChanges || fetchState != changesResponse.newState {
//                try await syncIdentities(account: account)
//            }
//
//        }else{
//            account.identityState = try await fetchIdentities(account: account)
//        }
//
//    }
//
//    //returns Identity object state on server
//    private func fetchIdentities(account: CDAccount, ids:[JMAPid]? = nil) async throws -> String? {
//        guard let accountId = account.uid else {
//            throw PersistenceError.requiredAttributeMissing
//        }
//
//        let requestData = try JMAPIdentity.GetCall(accountId: accountId).requestData()
//        print(try JSONSerialization.jsonObject(with: requestData))
//        let responseData = try await session.call(data: requestData)
//        print(try JSONSerialization.jsonObject(with: responseData))
//        let identityResponse = try JMAPIdentity.GetResponse(responseData: responseData,
//                                                          accountId: accountId,
//                                                            sessionState: session.raw.state)
//
//        let remoteIdentities = identityResponse.list
//        try CDIdentity.mergeIdentities(in: account, with: remoteIdentities)
//
//        return identityResponse.state != "" ? identityResponse.state : nil
//    }
//
//    private func removeIdentities(ids: [JMAPid], from account: CDAccount) throws {
//        guard let context = account.managedObjectContext else {
//            return
//        }
//
//        for id in ids {
//            let predicate = NSPredicate(format: "serverSetId == %@ AND account == %@", id, account)
//            let fetchRequest = CDIdentity.fetchRequest(predicate)
//            let results = try context.fetch(fetchRequest)
//            if results.count != 1 {
//                throw PersistenceError.expectedObjectMissing
//            }
//            account.managedObjectContext?.delete(results[0])
//        }
//    }
//
    // MARK: - Implementation - Fetch working set
    private func updateEmails(from email: String) {
        
    }
    
    private func initializeEmails(from email: String) {
//        let filter = JMAPQueryCall.Filter.filterCondition(["from": email])
//        let comparator = JMAPQueryCall.Comparator(property: "receivedAt", isAscending: false)
//        let emailIdCall = JMAPEmail.QueryCall(accountId: accountId,
//                                              filter: filter,
//                                              sort: [comparator],
//                                              calculateTotal: true)
    }

}

//prototyping, will deprecate
extension JMAPSession {
    
    //  MARK: - specified fetches
    func mailboxes(in accountId:JMAPid, ids:[JMAPid]? = nil) async throws -> JMAPResponse<JMAPMailbox.GetResponse> {
        let requestData = try JMAPMailbox.GetCall(accountId: accountId).requestData()
        let responseData = try await call(data: requestData)
        
        return try JMAPResponse<JMAPMailbox.GetResponse>.fromQuery(data: responseData)
    }
    
    func emailQuery(mailboxId: JMAPid, accountId: JMAPid) async throws -> [JMAPid]? {
        //need an email query object
        let filter = JMAPQueryCall.Filter.filterCondition(["inMailbox": mailboxId])
        let comparator = JMAPQueryCall.Comparator(property: "receivedAt", isAscending: false)
        let queryCall = JMAPEmail.QueryCall(accountId: accountId,
                                            filter: filter,
                                            sort: [comparator],
                                            position: 0,
                                            calculateTotal: true)
        let requestData = try queryCall.requestData()
        
        let responseData = try await call(data: requestData)
        
        //TODO : need to replace with generic code
        let responseObject = try JMAPResponse<JMAPEmail.QueryResponse>.fromQuery(data: responseData)
        
        let ids = responseObject.methodResponses.first?.args.ids
        return ids
        
        //        let responseObject = try JMAPEmail.QueryResponse(responseData: {}, accountId: <#T##JMAPid#>, indexedSession: <#T##IndexedSession#>)
    }
    
    func threadIds(in mailboxId:JMAPid, accountId: JMAPid) async throws -> [JMAPid]? {
        //"0"
        let filter = JMAPQueryCall.Filter.filterCondition(["inMailbox": mailboxId])
        let comparator = JMAPQueryCall.Comparator(property: "receivedAt", isAscending: false)
        let emailIDCall = JMAPEmail.QueryCall(accountId: accountId,
                                              filter: filter,
                                              sort: [comparator],
                                              position: 0,
                                              calculateTotal: true)
        
        
        //"1"
        let threadIdResultRef = JMAPResultReference(resultOf: "0", name: JMAPEmail.QueryCall.methodName(), path: "/ids")
        let threadIDCall = JMAPEmail.RelGetCall(accountId: accountId, ids: threadIdResultRef, properties: ["threadId"] )
        
        //"2"
        let threadResultRef = JMAPResultReference(resultOf: "1", name: JMAPEmail.RelGetCall.methodName(), path: "/list/*/threadId")
        let threadCall = JMAPThread.RelGetCall(accountId: accountId, ids: threadResultRef)
        
        
        //construct it
        let constructor = JMAPRequestConstructor(using: JMAPSession.Constants.MailCapabilities)
        let methods = [emailIDCall, threadIDCall, threadCall] as [JMAPMethod]
        var count = 0
        for method in methods {
            constructor.addInvocation(object: [type(of: method).methodName(), try method.structuredRepresentation(), String(count)])
            count += 1
        }
        let data = try constructor.encode()
        let resultData = try await call(data: data)
        
        let resultObject = try JMAPResponseHeterogenous<Data>(from: resultData)
        
        //we get back interim results, but only interested in the last one, which we know to be of type Thread/get
        guard let finalResponse = resultObject.methodResponses.last else {
            return nil
        }
        let responseObject = try JSONDecoder().decode(JMAPInvocation< JMAPThread.GetResponse>.self, from: finalResponse)
        
        // now have a set of emailIds
        let results = responseObject.args.list.flatMap{
            $0.emailIds
        }
        
        
        
        return results
    }
    

    
    
    //for prototyping purposes, not efficient to make a single request
    func getEmail(with emailId:JMAPid, accountId: JMAPid) async throws -> Any {
        let requestData = try JMAPEmail.GetCall(accountId: accountId, ids: [emailId]).requestData()
        let responseData = try await call(data: requestData)
        
//        let request = try urlRequest(method: method)
//        let data = try await JMAPSession.fetch(request: request)
//
        return try JSONSerialization.jsonObject(with: responseData)
    }
    

}
