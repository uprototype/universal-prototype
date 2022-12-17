//
//  LocalEmailIdentity.swift
//  uprototype
//
//  Created by Universal on 12/10/22.
//

import CoreData

class LocalEmailIdentity {
    let email: String
    var defaultName: String? = nil
    var names = Set<LocalNamedEmail> ()
    
    var managedObjectId : NSManagedObjectID? = nil
    
    required init(stored: CDLocalEmailIdentity) throws {
        guard let email = stored.address else {
            throw PersistenceError.requiredAttributeMissing
        }
        self.email = email
        defaultName = stored.name
        
        let alternateNames : [LocalNamedEmail]? = stored.names?.compactMap{
            guard let nameObj = ($0 as? CDLocalNamedEmail),
                  let name = nameObj.name else {
                return nil
            }
            return LocalNamedEmail(name: name, address: self)
        }
        if let alternateNames {
            self.names = Set(alternateNames)
        }
        managedObjectId = stored.objectID
    }
    
    required init(remote: EmailIdentityValue) throws {
        email = remote.email
        defaultName = remote.name
        if let remoteName = remote.name {
            let nameObj = LocalNamedEmail(name: remoteName, address: self)
            names.insert(nameObj)
        }
        try self.save()
    }
}

extension LocalEmailIdentity : CoreDataAbstraction{
    typealias InputType = EmailIdentityValue
    typealias NSManagedType = CDLocalEmailIdentity

    func merge(_ remote: EmailIdentityValue) throws {
        if let remoteName = remote.name {
            if defaultName == nil {
                defaultName = remote.name
            }
            let nameObj = LocalNamedEmail(name: remoteName, address: self)
            names.insert(nameObj)
        }
    }

    func save() throws {
        let context = PersistenceController.shared.newDataTaskContext()
        try context.performAndWait {
            var storedIdentity : CDLocalEmailIdentity
            if let managedObjectId {
                guard let identity = try context.existingObject(with: managedObjectId) as? CDLocalEmailIdentity else {
                    throw PersistenceError.expectedObjectMissing
                }
                storedIdentity = identity
            }else{
                storedIdentity = CDLocalEmailIdentity(context: context)
            }

            storedIdentity.name = defaultName
            storedIdentity.address = email
            for name in self.names {
                try name.save(in: storedIdentity, context: context)
            }
            try context.save()
            if managedObjectId == nil {
                managedObjectId = storedIdentity.objectID
            }
        }
    }
}

extension LocalEmailIdentity {
    static func allIdentityAddresses() throws -> [String] {
        let context = PersistenceController.shared.newDataTaskContext()
        return try context.performAndWait {
            let request = CDLocalEmailIdentity.fetchRequest()
            return try context.fetch(request).compactMap {
                return $0.address
            }
        }
    }
    
    static func received(_ input: EmailIdentityValue) {
        do{
            let context = PersistenceController.shared.newDataTaskContext()
            try context.performAndWait {
                if let storedIdentity = try CDLocalEmailIdentity.fetch(address: input.email, context: context) {
                    let identityObj = try LocalEmailIdentity(stored: storedIdentity)
                    try identityObj.merge(input)
                    try identityObj.save()
                }else{
                    let _ = try LocalEmailIdentity(remote: input)
                }
            }
        }catch{
            print("error receiving identity in relationship singleton")
        }
        
    }

}

// address, primary name
// one relationship, set of names
extension CDLocalEmailIdentity {
    static func fetchRequest(_ predicate: NSPredicate) -> NSFetchRequest<CDLocalEmailIdentity> {
        let request = NSFetchRequest<CDLocalEmailIdentity>(entityName: "CDLocalEmailIdentity")
        request.sortDescriptors = [NSSortDescriptor(key:"address", ascending: true)]
        request.predicate = predicate
        return request
    }
    
    static func fetch(address: String, context: NSManagedObjectContext ) throws -> CDLocalEmailIdentity? {
        let predicate = NSPredicate(format: "address == %@", address)
        let request = CDLocalEmailIdentity.fetchRequest(predicate)
        
        let results = try context.fetch(request)
        if results.count == 1 {
            return results[0]
        }else if results.count > 1 {
            throw PersistenceError.duplicateUniqueObject
        }
        return nil
    }
}
