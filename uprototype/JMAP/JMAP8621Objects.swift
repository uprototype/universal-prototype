//
//  JMAP8621Objects.swift
//  uprototype
//
//  Created by Mark Xue on 11/30/22.
//

import Foundation


// MARK: - Mailbox

struct JMAPMailbox : JMAPObject {
    let id: String
    let name: String
    let parentId: String?
    let role: Role?
    let sortOrder: UInt
    let totalEmails: UInt
    let unreadEmails: UInt
    let totalThreads: UInt
    let unreadThreads: UInt
    let isSubscribed : Bool
    let myRights : Rights
    
    enum Role : String , Codable {
        case all
        case archive
        case drafts
        case flagged
        case important
        case inbox
        case junk
        case scheduled //not defined in https://www.iana.org/assignments/imap-mailbox-name-attributes/imap-mailbox-name-attributes.xhtml
        case sent
        case subscribed
        case trash
    }
    
    struct Rights : Codable{
        let mayReadItems: Bool
        let mayAddItems: Bool
        let mayRemoveItems: Bool
        let maySetSeen: Bool
        let maySetKeywords: Bool
        let mayCreateChild: Bool
        let mayRename: Bool
        let mayDelete: Bool
        let maySubmit: Bool
    }
    
    static func name() -> String { return "Mailbox" }
}

extension JMAPMailbox {
    class GetCall: JMAPGetCall, JMAPMethod {
        static func methodName() -> String {
            return "Mailbox/get"
        }
    }
    
    class GetResponse: JMAPGetResponse<JMAPMailbox>, JMAPMethod {
        static func methodName() -> String {
            return "Mailbox/get"
        }
    }
    
    class ChangesCall: JMAPChangesCall, JMAPMethod {
        static func methodName() -> String {
            return "Mailbox/changes"
        }
    }
    
    class ChangesResponse: JMAPChangesResponse, JMAPMethod {
        static func methodName() -> String {
            return "Mailbox/changes"
        }
    }
    
    static func fromQuery(data: Data) throws -> [JMAPMailbox] {
        if let responseStrings = try? JSONDecoder().decode([String].self, from: data) {
            if responseStrings.first == "requestTooLarge" {
                throw JMAPRemoteError.requestTooLarge
            } else {
                throw JMAPRemoteError.unexpectedErrors(responseStrings)
            }
        }
        
        let decoded = try JSONDecoder().decode(JMAPResponse<JMAPMailbox.GetResponse>.self, from: data)

        return decoded.methodResponses.flatMap{ $0.args.list }
    }
}

// MARK: - Thread
struct JMAPThread : JMAPObject{
    let id: JMAPid
    let emailIds: [JMAPid]
    
    static func name() -> String { return "Thread" }
}
extension JMAPThread{
    class GetCall : JMAPGetCall, JMAPMethod {
        static func methodName() -> String {
            return "Thread/get"
        }
    }
    
    class RelGetCall : JMAPGetCallRelID, JMAPMethod {
        static func methodName() -> String {
            return "Thread/get"
        }
    }
    
    class GetResponse: JMAPGetResponse<JMAPThread>, JMAPMethod {
        static func methodName() -> String {
            return "Thread/get"
        }
    }
}


// MARK: - Email

struct JMAPEmail {
    
    class GetCall : JMAPGetCall, JMAPMethod {
        //if bodyProperties omitted, defaults to  [ "partId", "blobId", "size", "name", "type", "charset",
//        "disposition", "cid", "language", "location" ]
//        var bodyProperties: [String]? = nil
        var fetchHTMLBodyValues: Bool = false
//        var fetchAllBodyValues: Bool = false
//        var maxBodyValueBytes: UInt = 0
        
        static func methodName() -> String {
            return "Email/get"
        }
        
        //Encodable doesn't know about subclass unless overridden
        private enum CodingKeys: String, CodingKey {
//            case bodyProperties, fetchHTMLBodyValues, fetchAllBodyValues, maxBodyValueBytes
            case fetchHTMLBodyValues
        }
        
        override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
//            try container.encode(self.bodyProperties, forKey: .bodyProperties)
            try container.encode(self.fetchHTMLBodyValues, forKey: .fetchHTMLBodyValues)
//            try container.encode(self.fetchAllBodyValues, forKey: .fetchAllBodyValues)
//            try container.encode(self.maxBodyValueBytes, forKey: .maxBodyValueBytes)
        }
    }
    
    class RelGetCall : JMAPGetCallRelID, JMAPMethod {
        var bodyProperties: [String]? = nil
        var fetchHTMLBodyValues: Bool = false
        var fetchAllBodyValues: Bool = false
        var maxBodyValueBytes: UInt = 0
        
        static func methodName() -> String {
            "Email/get"
        }
        
//        //Encodable doesn't know about subclass unless overridden
//        private enum CodingKeys: String, CodingKey {
//            case bodyProperties, fetchHTMLBodyValues, fetchAllBodyValues, maxBodyValueBytes
//        }
//
//        override func encode(to encoder: Encoder) throws {
//            try super.encode(to: encoder)
//            var container = encoder.container(keyedBy: CodingKeys.self)
//            try container.encode(self.bodyProperties, forKey: .bodyProperties)
//            try container.encode(self.fetchHTMLBodyValues, forKey: .fetchHTMLBodyValues)
//            try container.encode(self.fetchAllBodyValues, forKey: .fetchAllBodyValues)
//            try container.encode(self.maxBodyValueBytes, forKey: .maxBodyValueBytes)
//        }
    }
    
    class QueryCall : JMAPQueryCall, JMAPMethod {
        var collapseThreads : Bool = false
        static func methodName() -> String {
            return "Email/query"
        }
    }
    
    class QueryResponse: JMAPQueryResponse, JMAPMethod {
        static func methodName() -> String {
            return "Email/query"
        }
    }
}


struct JMAPEmailFull {
    //metadata
    let id: JMAPid
    let blobId: JMAPid
    let threadId: JMAPid
    let mailboxIds: [JMAPid:Bool]
    //special treatment for $draft, $seen, $flagged, $answered. may need a type
    //forwarded, phishing, junk, not junk
    let keywords: [String:Bool]
    let size : UInt
    let receivedAt : Date
    
//    header parsed forms
    enum HeaderParsedForm {
        case raw(String)
        case text(String)
        case addresses([JMAPEmailAddress])
        case groupedAddresses([EmailAddressGroup])
        case messageIDs([String]?)
        case date(Date?)
        case URLs([String]?)
    }
    
    struct EmailAddressGroup {
        var name: String?
        var addresses: [JMAPEmailAddress]
    }
    
    struct EmailHeader {
        let name : String
        let value : String //in raw form
        // as, all
    }
    
    struct EmailBodyPart {
        let partId: String?
        let blobId: JMAPid?
        var size: UInt
        var headers: [EmailHeader]
    }
    //....
}

struct JMAPEmailAddress : Codable{
    var name: String?
    var email: String
    
    init (from object: [String:String]) throws {
        guard let email = object["email"] else {
            throw JMAPEmailError.missingField("email")
        }
        
        self.name = object["name"]
        self.email = email
    }
}

//Lots of email parsing
enum JMAPEmailError : Error {
    case multipleSenders
    case missingField(String)
    case multipleFromWithoutSender
}

// MARK: - Identity
struct JMAPIdentity : JMAPObject {
    let id: JMAPid //maps to serverSetId in Core Data
    let name: String //default ""
    let email: String //immutable
    let replyTo: [JMAPEmailAddress]?
    let bcc: [JMAPEmailAddress]?
    let textSignature: String //default ""
    let htmlSignature: String //default""
    let mayDelete: Bool
    
    static func name() -> String { return "Thread" }
}

extension JMAPIdentity {
    class GetCall: JMAPGetCall, JMAPMethod {
        static func methodName() -> String {
            return "Identity/get"
        }
        
        static func capabilities() -> [String] {
            return JMAPSession.Constants.MailSubmissionCapabilities
        }
    }
    
    class GetResponse: JMAPGetResponse<JMAPIdentity>, JMAPMethod {
        static func methodName() -> String {
            return "Identity/get"
        }
        
        static func capabilities() -> [String] {
            return JMAPSession.Constants.MailSubmissionCapabilities
        }
    }
    
    class ChangesCall: JMAPChangesCall, JMAPMethod {
        static func methodName() -> String {
            return "Identity/changes"
        }
        
        static func capabilities() -> [String] {
            return JMAPSession.Constants.MailSubmissionCapabilities
        }
    }
    
    class ChangesResponse: JMAPChangesResponse, JMAPMethod {
        static func methodName() -> String {
            return "Identity/changes"
        }
        
        static func capabilities() -> [String] {
            return JMAPSession.Constants.MailSubmissionCapabilities
        }
    }
}
