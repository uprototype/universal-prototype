//
//  MailCredentialStore.swift
//  uprototype
//
//  Created by Mark Xue on 10/26/22.
//

import SwiftUI

// prototyping with fastmail
// TODO: make this a picker or a default in a text entry field

/*
 Credential ViewModel
    Performs intents for the login view
    //deprecated backing store for list of credentials - now just a fetched result
 
*/
class MailCredentialModel : ObservableObject {
    let mailModel = MailMessageModel.shared
    var tokenField: String = ""
    @Published private(set) var credentials = [Credential]()
    
    // MARK: - Intent
    
    func login(){
        Task.detached{
            await self.mailModel.addJMAPCredential(token: self.tokenField)
        }
    }
}

extension UUID : Identifiable {
    public var id: UUID {
        return self
    }
}
