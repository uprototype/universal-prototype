//
//  uprototypeApp.swift
//  uprototype
//
//  Created by Mark Xue on 10/26/22.
//

import SwiftUI


@main
struct uprototypeApp: App {
    //start relationship processing of incoming events
    let relationshipModel = RelationshipModel.shared
    
    var body: some Scene {
        WindowGroup {
            TabView{
                ConversationView()
                    .environment(\.managedObjectContext, PersistenceController.shared.cacheContainer.viewContext)
                    .tabItem{
                        Label("Messages", systemImage: "bubble.right")
                    }
                SettingsView()
                    .environment(\.managedObjectContext, PersistenceController.shared.cacheContainer.viewContext)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }

        }
    }
}
