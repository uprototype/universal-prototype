//
//  LocalEmailIdentity.swift
//  uprototype
//
//  Created by Universal on 12/10/22.
//

import CoreData

extension LocalEmailIdentity {
    static func fetchRequest(_ predicate: NSPredicate) -> NSFetchRequest<LocalEmailIdentity> {
        let request = NSFetchRequest<LocalEmailIdentity>(entityName: "LocalEmailIdentity")
        request.sortDescriptors = [NSSortDescriptor(key:"address", ascending: true)]
        request.predicate = predicate
        return request
    }
    
    static func fetchOrCreate(address: String, context: NSManagedObjectContext ) throws -> LocalEmailIdentity {
        let predicate = NSPredicate(format: "address == %@", address)
        let request = LocalEmailIdentity.fetchRequest(predicate)
        
        let results = try context.fetch(request)
        if results.count == 1 {
            return results[0]
        }else if results.count > 1 {
            throw MailModelError.duplicateUniqueObject
        }
        
        let result = LocalEmailIdentity(context: context)
        result.address = address
        return result
    }
}
