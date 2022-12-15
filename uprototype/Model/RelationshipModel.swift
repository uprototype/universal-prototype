//
//  RelationshipModel.swift
//  uprototype
//
//  Created by Universal on 12/10/22.
//

import CoreData
import Combine

/*
 Model for persistent data (unlike MailMessageModel, a cache of data elsewhere)
*/

actor RelationshipModel : ObservableObject {
    static let shared = RelationshipModel()
    
    private var identitySink : AnyCancellable? = nil

    func connect(to mailModel: MailMessageModel){
        Task{
            identitySink = await MailMessageModel.shared.identitySubject.sink {value in
                LocalEmailIdentity.received(value)
            }
        }
    }
    
    func newRelationship(localEmail:String, localName:String, remoteEmail:String, remoteName:String, messageId: String) {
        
    }
}
