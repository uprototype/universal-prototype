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
}

//Gather API and implementation for MailMessageModel
extension RelationshipModel {
    
    //Setup Relationship Model to consume values from the cache
    // Specifically, identity to update local identity
    // emails to update relationships
    func connect(){
        Task{
            let mailModel = MailMessageModel.shared
            
            identitySink = await mailModel.identitySubject.sink {value in
                LocalEmailIdentity.received(value)
            }
        }
    }
    
    //not yet used
    func newRelationship(localEmail:String, localName:String, remoteEmail:String, remoteName:String, messageId: String) {
        
    }
    
    // MARK: - Implementation
    

//    private func updateThreads() {
//        do {
//            try LocalEmailIdentity.allIdentityAddresses().forEach { address in
//                Task {
//                    await MailMessageModel.shared.retrieveNewThreads(senderAddress: address)
//                }
//            }
//        }catch{
//            print("Error in updating Threads: \(error)")
//        }
//
//    }
}
