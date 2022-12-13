//
//  DebugState.swift
//  uprototype
//
//  Created by Universal on 12/6/22.
//

import Foundation

struct ProgressState {
    var description = String()
    var progress = 0.0
}

class DebugStateModel : ObservableObject {
    let mailModel = MailMessageModel.shared
    
    @Published var fetchState = ProgressState()
    @Published var resetState = ProgressState()
    
    // MARK: - Intents
    func fetch() {
        Task{
            await MailMessageModel.shared.fetch(observer: self)
        }
    }
    
    func reset() {
        PersistenceController.shared.resetCache(observer: self)
        Task{
            await MailMessageModel.shared.resetCache()
        }
    }
    
    func updateFetch(description: String, progress: Double) {
        DispatchQueue.main.async {
            self.fetchState.description = description
            self.fetchState.progress = progress
        }
    }
    
    func updateReset(description: String, progress: Double) {
        DispatchQueue.main.async {
            self.resetState.description = description
            self.resetState.progress = progress
        }
    }
}
