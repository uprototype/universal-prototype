//
//  JMAPSession+Methods.swift
//  uprototype
//
//  Created by Universal on 12/9/22.
//

import Foundation

//prototyping, will deprecate
extension JMAPSession {


    
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
