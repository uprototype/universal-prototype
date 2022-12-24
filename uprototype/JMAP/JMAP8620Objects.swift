//
//  JMAPObjects.swift
//  uprototype
//
//  Created by Mark Xue on 11/29/22.
//

import Foundation
import CoreData

typealias JMAPid = String

// MARK: - Session

//https://www.rfc-editor.org/rfc/rfc8620.html#section-2
struct JMAPSessionRaw : Decodable {
    //excluded from Decoder, filled in by initializer
    var capabilities = [String:Any]()
    var newKeys = [String:Any]()
    
    var accounts : [JMAPid:JMAPAccount]
    var primaryAccounts : [String:JMAPid]
    var username : String
    var apiUrl : URL
    var downloadUrl : String //is url format, so doesn't parse as a URL
    var uploadUrl : String //is url format, so doesn't parse as a URL
    var state : String
    var eventSourceUrl : URL
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case primaryAccounts, username, accounts
        case apiUrl, downloadUrl, uploadUrl, state, eventSourceUrl
    }

    init (from jsonData: Data) throws {
        guard var rootJSONdict = try? JSONSerialization.jsonObject(with: jsonData) as? [String:Any],
              let capabilityObject = rootJSONdict["capabilities"] as? [String:Any] else {
            throw JMAPDataError.parseJMAPSessionFail
        }

        
        let codingKeys = Set(CodingKeys.allCases.map{ $0.rawValue })
        var collectKeys = [String:Any] ()
        //move unexpected keys to newKeys dict
        for key in rootJSONdict.keys {
            if !codingKeys.contains(key) {
                collectKeys[key] = rootJSONdict[key]
                rootJSONdict.removeValue(forKey: key)
            }
        }
        let cleanedJSONdata = try JSONSerialization.data(withJSONObject: rootJSONdict)
        let decoded = try JSONDecoder().decode(JMAPSessionRaw.self, from: cleanedJSONdata)
        self = decoded
        capabilities = capabilityObject
        newKeys = collectKeys
    }
}

struct JMAPCoreCapabilities : Decodable{
    var maxSizeUpload: UInt
    var maxConcurrentUpload: UInt
    var maxSizeRequest: UInt
    var maxConcurrentRequests : UInt
    var maxCallsInRequest : UInt
    var maxObjectsInGet : UInt
    var maxObjectsInSet : UInt
    var collationAlgorithms : [String]
}

/*
 Goal of Request/Response objects is to produce a JSON data representation for the HTTP body of JMAPSession.urlrequest
Or to parse a complementary HTTP body response from the server
 
Simple approach is to parametrize the objects for a specific method for strongly typed requests using Codable

Complex approach to support heterogenous Invocations is with a constructor
 - client code instantiates a constructor
    - feeds it heterogenous Invocations in an order it understands
    - class translates Invocation -> Data -> [Any] to populate an [Any] object hierarchy
    - when done class translates [Any] -> Data using JSONSerializaion
 
Similarly, client code, expecting response Invocations in the same order, gives data to a decoder object.
    - spits out [invocation] as [Data]
    - client can then attempt typed decode
 
 */
// MARK: - JMAP Response
//https://www.rfc-editor.org/rfc/rfc8620.html#section-3.4

//Simplest to parametrize this with a specific method
// - absent a way to declare a request/response type with heterogenous methods
struct JMAPResponse<Method: JMAPMethod> : Decodable {
    let methodResponses: [JMAPInvocation<Method>]
    let sessionState: String
    let createdIDs : [String:String]? 
    let latestClientVersion: String? //not in RFC but present in Fastmail return objects
}

struct JMAPResponseHeterogenous<T> {
    var methodResponses : [T] //reencoded by JSONserialization for typed decoding
    let sessionState: String
    let createdIds: [String:String]?
    let latestClientVersion: String?
    
    init(from data: Data) throws {
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String:Any] else {
            throw JMAPRemoteError.JSONDecodingError
        }
        guard let sessionState = jsonObject["sessionState"] as? String,
            let methodResponseObjects = jsonObject["methodResponses"] as? [Any] else {
            throw JMAPRemoteError.missingField("Response object")
        }
        self.sessionState = sessionState
        createdIds = jsonObject["createdIds"] as? [String:String]
        latestClientVersion = jsonObject["latestClientVersion"] as? String
        
        methodResponses = [T]()
        
        // Only 2 supported parameters, avoids duplicating manual parsing code earlier in init or unnecessarily serializing obj back into data
        if T.self == Data.self {
            for responseObject in methodResponseObjects {
                let data = try JSONSerialization.data(withJSONObject: responseObject) as! T
                methodResponses.append(data)
            }
        }else if T.self == [Any].self {
            for responseObject in methodResponseObjects {
                if let listObject = responseObject as? T {
                    methodResponses.append(listObject)
                }
            }
        }else{
            throw JMAPDataError.unwrapResponseFailure
        }
    }
    
}

extension JMAPResponse {
    static func fromQuery(data: Data) throws -> Self {
        if let responseStrings = try? JSONDecoder().decode([String].self, from: data) {
            if responseStrings.first == "requestTooLarge" {
                throw JMAPRemoteError.requestTooLarge
            } else {
                throw JMAPRemoteError.unexpectedErrors(responseStrings)
            }
        }
        
        do {
            return try JSONDecoder().decode(Self.self, from: data)
        }catch{
            let obj = try JMAPResponseHeterogenous<[Any]>(from: data)
            if let method = obj.methodResponses.first?.first as? String,
               method == "error" {
                throw JMAPRemoteError.methodError( obj.methodResponses.first?[1] )
                
            }
            throw error
        }
    }
}

// MARK: - JMAP Request
//https://www.rfc-editor.org/rfc/rfc8620.html#section-3.3

//Factory/Constructor

class JMAPRequestConstructor {
    private var storage = [String:Any?]()
    private var invocations = [[Any]]()
    
    init(using: [String], createdIDs : [String:String]? = nil) {
        storage["using"] = using
//        storage["methodCalls"] = invocations
        storage["createdIds"] = createdIDs
    }
    
    //invocations are passed in without knowledge of their type structure (the caller knows)
    func addInvocation(object:[Any]) {
        invocations.append(object)
    }
    
    func encode() throws -> Data {
        storage["methodCalls"] = invocations
        return try JSONSerialization.data(withJSONObject: storage)
    }
}


//we handle simple reqests and responses for a single method
struct JMAPRequest<Method: JMAPMethod> : Encodable{
    let using : [String]
    var methodCalls : [JMAPInvocation<Method>]
    var createdIDs : [String:String]? = nil
}

//https://www.rfc-editor.org/rfc/rfc8620.html#section-3.2
/* want to produce this as an array */
struct JMAPInvocation<Method: JMAPMethod>{
    let name : String
    let args : Method
    let methodCallID : String

    init (arguments:Method, methodCallID: String = "0") {
        self.name = Method.methodName()
        self.args = arguments
        self.methodCallID = methodCallID
    }
}


extension JMAPInvocation : Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(name)
        try container.encode(args)
        try container.encode(methodCallID)
    }
}

extension JMAPInvocation : Decodable {
//    enum CodingKeys : CodingKey {
//        case name, args, methodCallID
//    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.name = try container.decode(String.self)
        self.args = try container.decode(Method.self)
        self.methodCallID = try container.decode(String.self)
    }
}

// MARK: - Protocols
//strictly speaking, needs not just to be codable, but to be represented as a keyed container

protocol JMAPMethod : Codable{
    var accountId: String { get }
    static func methodName() -> String
    static func capabilities() -> [String]
    func structuredRepresentation () throws -> Any
}

extension JMAPMethod {
    static func capabilities() -> [String] {
        return JMAPSession.Constants.MailCapabilities
    }
}

//E.g. Mailbox, Email, Thread, etc
protocol JMAPObject : Codable {
    static func name() -> String
}

extension Encodable {
    func structuredRepresentation() throws -> Any {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data)
    }
}

// MARK: - Methods
//to implement additional fields, subclass
class JMAPGetCall : Codable{
    let accountId: JMAPid
    let ids: [JMAPid]?
    let properties: [String]?

    init(accountId: JMAPid, ids: [JMAPid]? = nil, properties: [String]? = nil) {
        self.accountId = accountId
        self.ids = ids
        self.properties = properties
    }
    
//    func structuredRepresentation() throws -> Any {
//        let data = try JSONEncoder().encode(self)
//        return try JSONSerialization.jsonObject(with: data)
//    }
}

class JMAPGetCallRelID : Codable{
    let accountId: JMAPid
    let ids: JMAPResultReference
    let properties: [String]?
    
    enum CodingKeys : String, CodingKey {
        case accountId, ids = "#ids", properties
    }

    init(accountId: JMAPid, ids: JMAPResultReference, properties: [String]? = nil) {
        self.accountId = accountId
        self.ids = ids
        self.properties = properties
    }
}

//https://www.rfc-editor.org/rfc/rfc8621.html#section-2
class JMAPGetResponse<Object:JMAPObject> : Codable {
    let accountId: String
    let state: String
    let list: [Object]
    let notFound: [String]
    
    func structuredRepresentation() throws -> Any {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data)
    }
}

//use this when only specific fields are specified. Need to specify field value types
class JMAPGetResponseConstrained {
    let accountId: String
    let state: String
    let list: [[String:Any]]
    let notFound: [String]
    
    //gets called with an element in the list object from an Invocation as a [String:Any]
    init(from listObject: [String:Any]) throws {
        guard let accountId = listObject["accountId"] as? String,
              let list = listObject["list"] as? [[String:Any]],
              let state = listObject["state"] as? String,
        let notFound = listObject["notFound"] as? [String] else {
            throw JMAPRemoteError.JSONDecodingError
        }
        self.accountId = accountId
        self.list = list
        self.state = state
        self.notFound = notFound
    }
}

class JMAPQueryCall : Codable {
    let accountId: JMAPid
    let filter: Filter?
    let sort: [Comparator]?
    let position: Int
    let anchor: Int?
    var anchorOffset : Int
    let limit: UInt?
    var calculateTotal: Bool = false
    
    init(accountId: String, filter: Filter?, sort: [Comparator]?,
         position: Int = 0, anchor: Int? = nil, anchorOffset: Int = 0, limit: UInt? = nil, calculateTotal: Bool) {
        self.accountId = accountId
        self.filter = filter
        self.sort = sort
        self.position = position
        self.anchor = anchor
        self.anchorOffset = anchorOffset
        self.limit = limit
        self.calculateTotal = calculateTotal
        
    }
    
    indirect enum Filter : Codable{
        case filterOperator(FilterOperator)
        case filterCondition([String:String])
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self{
            case .filterCondition(let filterMap):
                try container.encode(filterMap)
            case .filterOperator(let filterOperator):
                try container.encode(filterOperator)
            }
        }
    }
    
    struct FilterOperator : Codable{
        let operator_ : JMAPOperator
        let conditions : Filter
        
        enum CodingKeys : String, CodingKey {
            case operator_ = "operator"
            case conditions = "conditions"
        }
    }
    
    enum JMAPOperator : String, Codable {
        case AND
        case OR
        case NOT
    }
    
    enum JMAPCondition : Codable {
        case FilterOperator
        case FilterCondition
    }
    
    struct Comparator : Codable {
        let property: String
        let isAscending: Bool?
        var collation: String? = nil
    }
}

class JMAPQueryResponse : Codable {
    let accountId: JMAPid
    let queryState: String
    let canCalculateChanges: Bool
    let position: UInt
    let ids: [JMAPid]
    var total: UInt? = nil
    var limit: UInt? = nil
    
    //may also respond with :
    //anchor not found
    //unsupportedSort
    //unsupportedFilter
}

struct JMAPResultReference : Codable{
    let resultOf: String
    let name: String
    let path: String
}

// MARK: - Changes
//https://www.rfc-editor.org/rfc/rfc8620.html#section-5.2
class JMAPChangesCall : Codable {
    let accountId: JMAPid
    let sinceState: String
    let maxChanges: UInt?
    
    init(accountId: JMAPid, sinceState: String, maxChanges: UInt? = nil) {
        self.accountId = accountId
        self.sinceState = sinceState
        self.maxChanges = maxChanges
    }
}

extension JMAPMethod  {
    func requestData() throws -> Data {
        let invocation = JMAPInvocation(arguments: self)
        let request = JMAPRequest(using: type(of: self).capabilities(), methodCalls: [invocation] )
        return try JSONEncoder().encode(request)
    }
    
    
    //initializes based on Response containing a single Invocation of this method
    init(responseData:Data, accountId:JMAPid, sessionState: String) throws {
        let responseObject = try JMAPResponse<Self>.fromQuery(data: responseData)
        guard responseObject.sessionState == sessionState else {
            throw MailModelError.sessionInvalid
        }
        
        let responses = responseObject.methodResponses
        guard responses.count == 1,
              let invocation = responses.first,
              invocation.name == Self.methodName(),
              invocation.args.accountId == accountId else {
            throw JMAPRemoteError.responseMismatch
        }
        
        self = invocation.args
    }
}

class JMAPChangesResponse: Codable {
    let accountId: JMAPid
    let oldState: String
    let newState: String
    let hasMoreChanges: Bool
    let created: [JMAPid]
    let updated: [JMAPid]
    let destroyed: [JMAPid]
}
