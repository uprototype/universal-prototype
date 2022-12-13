//
//  EmailAddress.swift
//  uprototype
//
//  Created by Universal on 12/5/22.
//

import CoreData

extension EmailAddress {
    static func fetchRequest(_ predicate: NSPredicate) -> NSFetchRequest<EmailAddress> {
        let request = NSFetchRequest<EmailAddress>(entityName: "EmailAddress")
        request.sortDescriptors = [NSSortDescriptor(key:"address", ascending: true)]
        request.predicate = predicate
        return request
    }
    
    static func fetchOrCreate(address: String, context: NSManagedObjectContext ) throws -> EmailAddress {
        let predicate = NSPredicate(format: "address == %@", address)
        let request = EmailAddress.fetchRequest(predicate)
        
        let results = try context.fetch(request)
        if results.count == 1 {
            return results[0]
        }else if results.count > 1 {
            throw MailModelError.duplicateUniqueObject
        }
        
        let result = EmailAddress(context: context)
        result.address = address
        return result
    }
}
    
