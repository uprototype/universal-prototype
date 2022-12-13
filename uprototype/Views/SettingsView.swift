//
//  SettingsView.swift
//  uprototype
//
//  Created by Mark Xue on 10/26/22.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject var debugModel = DebugStateModel()
    
    var body: some View {
        NavigationView{
            List {
                NavigationLink {
                    CredentialsView()
                } label :{
                    Text("Credentials")
                }
                Section(header: Text("Relationships")) {
                    NavigationLink {
                        RelationshipSettingsView().environment(\.managedObjectContext, PersistenceController.shared.dataContainer.viewContext)
                    } label :{
                        Text("Identities")
                    }
                    
                }
                Section(header: Text("Debug")) {
                    NavigationLink {
                        AccountsView()
                    } label :{
                        Text("Accounts")
                    }
                    NavigationLink {
                        List{
                            MailboxesView()
                        }
                    } label :{
                        Text("Mailboxes")
                    }
                }
                Section(header: Text("Debug")) {
                    VStack{
                        Button("Refetch Data"){
                            debugModel.fetch()
                        }
                        ProgressView(value: debugModel.fetchState.progress) {
                            Text(debugModel.fetchState.description).font(.caption)
                        }
                    }
                    VStack{
                        Button("Reset all but Credentials"){
                            debugModel.reset()
                            
                        }.foregroundColor(.red)
                        ProgressView(value: debugModel.resetState.progress) {
                            Text(debugModel.resetState.description).font(.caption)
                        }
                    }
                }
            }
        }
    }
}

struct RelationshipSettingsView : View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LocalEmailIdentity.address, ascending: true)],
        animation: .default)
    private var identities: FetchedResults<LocalEmailIdentity>
    
    var body: some View {
        ForEach(identities) { identity in
            Text(identity.address ?? "")
        }
    }
}

struct loginFormView : View {
    @StateObject var mailCredential = MailCredentialModel()
    
    var body : some View {
        VStack{
            Text("Add an Account")
            HStack{
                Spacer()
                Form {
                    Section(header: Text("JMAP credentials")) {
                        SecureField("API token", text: $mailCredential.tokenField)
                        Button{
                            mailCredential.login()
                        } label: {
                            Text("Login")
                        }
                    }
                }
                Spacer()
                
            }
        }
    }
}

struct CredentialsView : View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDCredential.uuid, ascending: true)],
        animation: .default)
    private var credentials: FetchedResults<CDCredential>
    
    var body : some View {
        VStack{
            if !credentials.isEmpty{
                List {
                    ForEach (credentials) { credential in
                        NavigationLink {
                            AccountsView(credential)
                        } label: {
                            HStack{
                                if let username = credential.userName{
                                    Label(username,
                                          systemImage: "dot.radiowaves.left.and.right")
                                }else{
                                    Label(credential.sessionURL?.description ?? "empty credential",
                                          systemImage: "dot.radiowaves.left.and.right").symbolVariant(.slash).foregroundColor(.gray)
                                }
                            }
                        }
                    }.onDelete(perform: deleteItems)
                }
            }
            loginFormView()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { credentials[$0] }.forEach { credential in
                Task {
                    await MailMessageModel.shared.delete(credential: credential)
                }
            }
        }
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {

    static var previews: some View {
        SettingsView()
    }
}
