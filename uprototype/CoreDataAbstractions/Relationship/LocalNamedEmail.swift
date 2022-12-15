//
//  LocalNamedEmail.swift
//  uprototype
//
//  Created by Universal on 12/14/22.
//

import CoreData

class LocalNamedEmail {
    let name: String
    weak var address : LocalEmailIdentity?
    var managedObjectId : NSManagedObjectID? = nil
    
    init(name: String, address: LocalEmailIdentity? = nil) {
        self.name = name
        self.address = address
    }
}

extension LocalNamedEmail : Hashable {
    static func == (lhs: LocalNamedEmail, rhs: LocalNamedEmail) -> Bool {
        return lhs.name == rhs.name && lhs.address?.email == rhs.address?.email
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        if let address = address?.email{
            hasher.combine(address)
        }
    }
}

extension LocalNamedEmail {
    func save(in storedIdentity:CDLocalEmailIdentity, context: NSManagedObjectContext) throws {
        var nameObj : CDLocalNamedEmail
        if let objId = managedObjectId {
            guard let object = try context.existingObject(with: objId) as? CDLocalNamedEmail else {
                throw PersistenceError.expectedObjectMissing
            }
            nameObj = object
        }else{
            nameObj = CDLocalNamedEmail(context: context)
        }
        
        nameObj.name = name
        nameObj.address = storedIdentity
        try context.save()
        if managedObjectId == nil {
            managedObjectId = nameObj.objectID
        }
    }
//
//    static func insert(name: String, address: LocalEmailIdentity, context: NSManagedObjectContext = PersistenceController.shared.newDataTaskContext() ) throws {
//        let newObject = LocalNamedEmail(name: name, address: address)
//        try context.performAndWait {
//            let addressObj = try address.managedObject(context: context)
//            var nameObj = CDLocalNamedEmail(context: context)
//            nameObj.name = name
//            nameObj.address = addressObj
//            try context.save()
//        }
//
//    }
}

extension CDLocalNamedEmail {
    static func fetchRequest(_ predicate: NSPredicate) -> NSFetchRequest<CDLocalNamedEmail> {
        let request = NSFetchRequest<CDLocalNamedEmail>(entityName: "CDLocalNamedEmail")
        request.sortDescriptors = [NSSortDescriptor(key:"name", ascending: true)]
        request.predicate = predicate
        return request
    }
    
    static func fetchOrCreate(name: String, address: String, context: NSManagedObjectContext ) throws -> CDLocalEmailIdentity {
        let predicate = NSPredicate(format: "name == %@ AND address.address = %@", name, address)
        let request = CDLocalEmailIdentity.fetchRequest(predicate)
        
        let results = try context.fetch(request)
        if results.count == 1 {
            return results[0]
        }else if results.count > 1 {
            throw PersistenceError.duplicateUniqueObject
        }
        
        let result = CDLocalEmailIdentity(context: context)
        result.address = address
        return result
    }
}
