//
//  AccountDetailView.swift
//  uprototype
//
//  Created by Mark Xue on 11/16/22.
//

import SwiftUI
import CoreData

struct AccountsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDAccount.uid, ascending: true)],
        animation: .default)
    private var items: FetchedResults<CDAccount>
    
    init(){
        
    }
    
    init(_ credential: CDCredential) {
        let predicate = NSPredicate(format: "credential == %@", credential)
        _items = FetchRequest(fetchRequest: CDAccount.fetchRequest(predicate))
    }
    
    var body: some View {
        VStack{
            Text("Accounts")
            List{
                ForEach(items){ item in
                    NavigationLink {
                        List{
                            Section(header: Text("Mailboxes")) {
                                MailboxesView(item)
                            }
                            Section(header: Text("Identities")) {
                                IdentitiesView(item)
                            }
                        }
                    } label : {
                        VStack(alignment: .leading){
                            Text(item.name ?? "unnamed Account")
                            if let credential = item.credential, let urlString = credential.sessionURL?.absoluteString{
                                Text(urlString)
                                    .foregroundColor(.gray).font(.caption)
                            }else{
                                Text("inactive")
                                    .foregroundColor(.gray).font(.caption)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct MailboxesView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDMailbox.name, ascending: true)],
        animation: .default)
    private var items: FetchedResults<CDMailbox>
    
    //for use for debug view where it is not anchored on an account
    init() {}
    
    init(_ account: CDAccount) {
        let predicate = NSPredicate(format: "account == %@", account)
        let request = CDMailbox.fetchRequest(predicate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDMailbox.name, ascending: true)]
        _items = FetchRequest(fetchRequest: request)

    }
    
    var body: some View {
        ForEach(items){ item in
            NavigationLink{
                MailboxMessageListView(item)
            } label: {
                VStack(alignment: .leading){
                    Text(item.name ?? "unnamed Mailbox")
                    if let role = item.role{
                        Text(role)
                            .foregroundColor(.gray).font(.caption)
                    }
                }
            }
        }
    }
}

struct IdentitiesView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDIdentity.email, ascending: true)],
        animation: .default)
    private var items: FetchedResults<CDIdentity>
    
    init(_ account: CDAccount) {
        let predicate = NSPredicate(format: "account == %@", account)
        let request = CDIdentity.fetchRequest(predicate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDIdentity.name, ascending: true)]
        _items = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        ForEach(items){ item in
            VStack(alignment: .leading){
                Text(item.name ?? "unnamed Mailbox")
            }
        }
        
    }
}

struct MailboxMessageListView : View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Email.receivedAt, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Email>
    var mailbox: CDMailbox
    
    init(_ mailbox: CDMailbox) {
        let predicate = NSPredicate(format: "mailboxes CONTAINS %@", mailbox)
        let request = Email.fetchRequest(predicate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Email.receivedAt, ascending: true)]
        _items = FetchRequest(fetchRequest: request)
        self.mailbox = mailbox
    }
    
    var body: some View {
        VStack{
            Text("Emails in \(mailbox.name ?? "Empty Name")")
//            List{
//                ForEach(mailbox.messages) { message in
//                    Label(message.description)
//                }
//            }
        }
    }
}

struct AccountsView_Previews: PreviewProvider {
    static var previews: some View {
        AccountsView()
    }
}
