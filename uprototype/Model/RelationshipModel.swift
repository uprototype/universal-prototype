//
//  RelationshipModel.swift
//  uprototype
//
//  Created by Universal on 12/10/22.
//

import Foundation
import CoreData

/*
 Model for persistent data (unlike MailMessageModel, a cache of data elsewhere)
*/

actor RelationshipModel : ObservableObject {
    static let shared = RelationshipModel()
    
    func newLocalIdentity(email:String, name: String) throws {
//        let dataContext = PersistenceController.shared.newDataTaskContext()
//        let localEmailIdentity = try LocalEmailIdentity.fetchOrCreate(address: email, context: dataContext)
//        
//        
//        let names = Set( localEmailIdentity.names?.compactMap{ return $0.name } )
//        if !names.contains( name ){
//            var namedEmail = LocalNamedEmail(context: dataContext)
//            namedEmail.name = name
//            namedEmail.address = localEmailIdentity
//        }
//        try dataContext.save()
    }
    
    func newRelationship(localEmail:String, localName:String, remoteEmail:String, remoteName:String, messageId: String) {
        
    }
}
