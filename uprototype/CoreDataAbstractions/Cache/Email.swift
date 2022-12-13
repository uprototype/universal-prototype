//
//  Email.swift
//  uprototype
//
//  Created by Mark Xue on 11/30/22.
//

import CoreData

extension Email {
    static func fetchRequest(_ predicate: NSPredicate) -> NSFetchRequest<Email> {
        let request = NSFetchRequest<Email>(entityName: "Email")
        request.sortDescriptors = [NSSortDescriptor(key:"receivedId", ascending: true)]
        request.predicate = predicate
        return request
    }
    
    static func fetch(messageId: JMAPid) -> Email? {
        let context = PersistenceController.shared.newCacheTaskContext()
        let predicate = NSPredicate(format: "id_ == %@", messageId)
        
        let request = Email.fetchRequest(predicate)
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
    

    
//    use JMAPGetResponseConstrained to request subset of email fields that are locally relevant
//    Parking function here as the set of fields is dependent on what is implemented in Core Data, driven by the app's needs.
    static func fetchEmails(ids:[JMAPid], accountId: JMAPid, session:JMAPSession) async throws {
        let properties = [ "messageId",
                           "inReplyTo",
                           "references",
                           "sender",
                           "from",
                           "to",
                           "cc",
                           "bcc",
                           "replyTo",
                           "subject",
                           "sentAt",
                           "htmlBody",
                           "preview",
                           "bodyValues",
                           "mailboxIds",
                           "threadId"
                           
        ]
        let method = JMAPEmail.GetCall(accountId: accountId,
                                       ids: ids,
                                       properties: properties)
        method.fetchHTMLBodyValues = true

//        let request = try session.urlRequest(method: method)
        let requestData = try method.requestData()
        
//        let data = try await JMAPSession.fetch(request: request)
        let responseData = try await session.call(data: requestData)
        
        let responseObject = try JMAPResponseHeterogenous<[Any]>(from: responseData)
        //expect only a single invocation
        guard let responseInvocation = responseObject.methodResponses.first, responseObject.methodResponses.count == 1,
              responseInvocation.first as? String == "Email/get",
              responseInvocation.count == 3,
              let responseMethod = responseInvocation[1] as? [String:Any] else {
            throw JMAPRemoteError.unexpectedMethod
        }
        
        let methodResponse = try JMAPGetResponseConstrained(from: responseMethod)
        
        // TODO: - do something with the the state value on methodResponse
        
        let context = PersistenceController.shared.newCacheTaskContext()
        for fields in methodResponse.list{
            try populateEmail(from: fields, context: context)
        }
        try context.save()
            
    }
    
    static func populateEmail(from object:[String:Any], context: NSManagedObjectContext) throws {

        let sender : JMAPEmailAddress
        //https://www.rfc-editor.org/rfc/rfc5322#section-3.6.2
        //only allowed to have one sender. If null, take a singular from field
        if let senderFields = object["sender"] as? [[String:String]] {
            guard senderFields.count == 1 else {
                throw JMAPEmailError.multipleSenders
            }
            sender = try JMAPEmailAddress(from: senderFields[0])
        }else{
            guard let fromFields = object["from"] as? [[String:String]] else {
                throw JMAPEmailError.missingField("From")
            }
            guard fromFields.count == 1 else {
                throw JMAPEmailError.multipleFromWithoutSender
            }
            sender = try JMAPEmailAddress(from: fromFields[0])
        }
        
        guard let htmlBodyObj = object["htmlBody"] as? [[String:Any]], let htmlBodyBlobId = htmlBodyObj.first?["blobId"] as? String else {
            throw JMAPEmailError.missingField("htmlBodyBlobId")
        }
        guard let jmapId = object["id"] as? JMAPid else {
            throw JMAPEmailError.missingField("JMAP Object ID")
        }
        guard let threadId = object["threadId"] as? String else {
            throw JMAPEmailError.missingField("threadId")
        }
        
        
        
        guard let messageIds = object["messageId"] as? [JMAPid] else {
            throw JMAPRemoteError.missingField("messageId")
        }
        
        print(object)
        
        let email = Email(context: context)
        email.sender = NamedEmailAddress(context: context)
        email.sender?.name = sender.name
        email.sender?.emailAddress = try EmailAddress.fetchOrCreate(address: sender.email, context: context)
        
        email.htmlBody = htmlBodyBlobId
        email.jmapId = jmapId
        email.threadId = threadId
        email.htmlBodyBlobId = htmlBodyBlobId
        
    }
}


