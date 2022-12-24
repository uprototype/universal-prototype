//
//  Email.swift
//  uprototype
//
//  Created by Mark Xue on 11/30/22.
//

import CoreData

class Email {
    let id: JMAPid // serverSetId in Core Data
    let messageId: String? // RFC5322 message id
    
    //Header
    let sender: NamedEmail
    let from: Set<NamedEmail>
    let cc: Set<NamedEmail>
    let bcc: Set<NamedEmail>
    let replyTo: Set<NamedEmail>
    
    let receivedAt: Date?
    let sentAt: Date? //fallback for imported mail
    let subject: String
    let inReplyTo: EmailReference?
    let references: Set<EmailReference>
    
    //Body
    let preview: String
    let htmlBody: String
    let htmlBodyBlobId: JMAPid?
    
    var managedObjectId : NSManagedObjectID? = nil
    
    required init(stored: CDEmail) throws {
        guard let serverId = stored.serverSetId,
              let senderObj = stored.sender else {
            throw PersistenceError.requiredAttributeMissing
        }
        id = serverId
        self.messageId = stored.messageId?.messageId
        
        //Header
        sender = try NamedEmail(stored: senderObj)
        from = try NamedEmail.fromStored(set: stored.from)
        cc = try NamedEmail.fromStored(set: stored.cc)
        bcc = try NamedEmail.fromStored(set: stored.bcc)
        replyTo = try NamedEmail.fromStored(set: stored.bcc)
        
        receivedAt = stored.receivedAt
        sentAt = stored.sentAt
        subject = stored.subject ?? ""
        inReplyTo = try EmailReference(stored: stored.inReplyTo)
        references = try EmailReference.fromStored(set: stored.inReferenceTo)
        
        //Body
        preview = stored.preview ?? ""
        htmlBody = stored.htmlBody ?? ""
        htmlBodyBlobId = stored.htmlBodyBlobId
        
        managedObjectId = stored.objectID
        
        
    }
    
    struct Constants {
        static let properties = [ "messageId",
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
        
    }
    
//    //not taking a typed constructor
//    required init(remote: Any ){
//
//    }
    
}

struct NamedEmail {
    let email: String
    let name: String?
    
    init(stored: CDNamedEmailAddress) throws {
        guard let email = stored.emailAddress?.address else {
            throw PersistenceError.requiredAttributeMissing
        }
        self.email = email
        if stored.name == "" {
            self.name = nil
        }else{
            self.name = stored.name
        }
    }
    
    init?(stored: CDNamedEmailAddress?) throws {
        guard let stored else {
            return nil
        }
        try self.init(stored: stored)
    }
    
    static func fromStored(set: NSSet?) throws -> Set<NamedEmail> {
        guard let set = set as? Set<CDNamedEmailAddress> else {
            return Set<NamedEmail>()
        }
        let nameArray = try set.map{ item in
            return try NamedEmail(stored: item)
        }
        return Set(nameArray)
    }
}

//defining equality on the address only
extension NamedEmail : Hashable {
    static func == (lhs: NamedEmail, rhs: NamedEmail) -> Bool {
        return lhs.email == rhs.email
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(email)
    }
}

//lets us lazily fetch email references
enum EmailReference {
    case email(Email)
    case reference(String)
    
    init(stored: CDEmailReference) throws {
        guard let messageId = stored.messageId else {
            throw PersistenceError.requiredAttributeMissing
        }
        self = .reference(messageId)
    }
    
    init?(stored: CDEmailReference?) throws {
        guard let stored else {
            return nil
        }
        try self.init(stored: stored)
    }
    
    static func fromStored(set: NSSet?) throws -> Set<EmailReference> {
        guard let set = set as? Set<CDEmailReference> else {
            return Set<EmailReference>()
        }
        let referenceArray = try set.map { item in
            return try EmailReference(stored: item)
        }
        return Set(referenceArray)
    }
}

extension EmailReference: Hashable {
    static func == (lhs: EmailReference, rhs: EmailReference) -> Bool {
        return lhs.id() == rhs.id()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id())
    }
    
    private func id() -> String {
        switch self {
        case let .email(email):
            return email.messageId ?? ""
        case let .reference(reference):
            return reference
        }
    }
}


extension CDEmail {
    static func fetchRequest(_ predicate: NSPredicate) -> NSFetchRequest<CDEmail> {
        let request = NSFetchRequest<CDEmail>(entityName: "CDEmail")
        request.sortDescriptors = [NSSortDescriptor(key:"receivedId", ascending: true)]
        request.predicate = predicate
        return request
    }
    
    static func fetch(messageId: JMAPid) -> CDEmail? {
        let context = PersistenceController.shared.newCacheTaskContext()
        let predicate = NSPredicate(format: "id_ == %@", messageId)
        
        let request = CDEmail.fetchRequest(predicate)
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
//    static func fetchEmails(ids:[JMAPid], accountId: JMAPid, session:JMAPSession) async throws {
//        let method = JMAPEmail.GetCall(accountId: accountId,
//                                       ids: ids,
//                                       properties: Email.Constants.properties)
//        method.fetchHTMLBodyValues = true
//        let requestData = try method.requestData()
//
//        let responseData = try await session.call(data: requestData)
//
//        let responseObject = try JMAPResponseHeterogenous<[Any]>(from: responseData)
//        //expect only a single invocation
//        guard let responseInvocation = responseObject.methodResponses.first, responseObject.methodResponses.count == 1,
//              responseInvocation.first as? String == "Email/get",
//              responseInvocation.count == 3,
//              let responseMethod = responseInvocation[1] as? [String:Any] else {
//            throw JMAPRemoteError.unexpectedMethod
//        }
//
//        let methodResponse = try JMAPGetResponseConstrained(from: responseMethod)
//
//        // TODO: - do something with the the state value on methodResponse
//
//        let context = PersistenceController.shared.newCacheTaskContext()
//        for fields in methodResponse.list{
//            try populateEmail(from: fields, context: context)
//        }
//        try context.save()
//
//    }
    
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
        guard let serverSetId = object["id"] as? JMAPid else {
            throw JMAPEmailError.missingField("JMAP Object ID")
        }
        guard let threadId = object["threadId"] as? String else {
            throw JMAPEmailError.missingField("threadId")
        }
        
        
        
        guard let messageIds = object["messageId"] as? [JMAPid] else {
            throw JMAPRemoteError.missingField("messageId")
        }
        
        print(object)
        
        let email = CDEmail(context: context)
        email.sender = CDNamedEmailAddress(context: context)
        email.sender?.name = sender.name
//        email.sender?.emailAddress = try EmailAddress.fetchOrCreate(address: sender.email, context: context)
        
        email.htmlBody = htmlBodyBlobId
        email.serverSetId = serverSetId
        email.threadId = threadId
        email.htmlBodyBlobId = htmlBodyBlobId
        
    }
}

