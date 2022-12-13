//
//  JMAPSession.swift
//  uprototype
//
//  Created by Mark Xue on 10/29/22.
//

import Foundation

enum JMAPRemoteError : Error {
    case tokenNotAuthorized
    case sessionRequestFail(String)
    case missingJMAPCoreCapability
    case requestTooLarge
    case unexpectedMethod
    case unexpectedErrors([String])
    case unexpectedError(String)
    case missingField(String)
    case JSONDecodingError
    case responseMismatch
    case immutableFieldChanged
    case methodError(Any)
}

enum JMAPDataError : Error {
    case parseJMAPSessionFail
    case urlConversionError
    case JSONEncodingFailure
    case unwrapResponseFailure
}

enum JMAPParserError : Error {
    case unimplementedResponseMethod
    // Can only be Data or [String:Any]
    case unsupportedJMAPHeterogenousReponseTypeParameters
}


struct JMAPSession {
    let raw : JMAPSessionRaw
    let coreCapabilities: JMAPCoreCapabilities
    private let token : String
    
    struct Constants {
        static let MailCapabilities = ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"]
        static let MailSubmissionCapabilities = ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail",
            "urn:ietf:params:jmap:submission"]
        static let EmailBatchSize = 50
        static let fastmailResourceURL = "https://api.fastmail.com/jmap/session"
    }
    
    init(from jsonData: Data, token:String) throws {
        let rawSession = try JMAPSessionRaw(from: jsonData)
        //check for required "urn:ietf:params:jmap:core" capability
        guard let coreCapabilitiesJSON = rawSession.capabilities["urn:ietf:params:jmap:core"] else {
            throw JMAPRemoteError.missingJMAPCoreCapability
        }
        
        let coreCapData = try JSONSerialization.data(withJSONObject: coreCapabilitiesJSON)
        let coreCap = try JSONDecoder().decode(JMAPCoreCapabilities.self, from: coreCapData)
        raw = rawSession
        coreCapabilities = coreCap
        self.token = token
    }
    
    static func fetch(token: String, sessionURL : URL) async throws -> JMAPSession {
        var request = URLRequest(url: sessionURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            if (response as? HTTPURLResponse)?.statusCode == 401 {
                throw JMAPRemoteError.tokenNotAuthorized
            }
            throw JMAPRemoteError.sessionRequestFail(response.description)
        }
        return try JMAPSession(from: data, token: token)
    }
}

//needs to be a extension on Session to access to the token
extension JMAPSession {
    public func call(data: Data) async throws -> Data {
        var request = URLRequest(url: raw.apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = data
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            if (response as? HTTPURLResponse)?.statusCode == 401 {
                throw JMAPRemoteError.tokenNotAuthorized
            }
            throw JMAPRemoteError.sessionRequestFail(response.description)
        }
        return data
    }
}

// MARK: - Account
struct JMAPAccount : Decodable{
    var name: String
    var isPersonal: Bool
    var isReadOnly: Bool
    var accountCapabilities = [String : Any]()
    
    private enum CodingKeys: String, CodingKey {
        case name, isPersonal, isReadOnly
    }
}
