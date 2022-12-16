//
//  CoreDataAbstracted.swift
//  uprototype
//
//  Created by Universal on 12/13/22.
//

import CoreData

enum PersistenceError : Error {
    case requiredAttributeMissing
    case expectedObjectMissing
    case duplicateUniqueObject
    case abstractObjectWithoutStoredCopy
}

//behavior of the center object in the relationship
//JMAPObject <> Object <> CDObject
protocol CoreDataAbstraction {
    associatedtype InputType
    associatedtype NSManagedType
    var managedObjectId : NSManagedObjectID? { get }
    
    init(stored: NSManagedType) throws
    init(remote: InputType) throws
    
    func merge(_ remote: InputType) throws
    func save() throws

    func managedObject(context:NSManagedObjectContext) throws -> NSManagedType
}

protocol AccountAbstractedObject : CoreDataAbstraction where NSManagedType : AccountScoped {
    static func store(_ value:InputType, in account:Account, context: NSManagedObjectContext) throws
    static func findMananged(like remote:InputType, in account:Account, context: NSManagedObjectContext) throws -> NSManagedType?
    static func insert(_ remote:InputType, in account:Account, context: NSManagedObjectContext) throws

    static func processObjects(state: String, account: Account, objects: [InputType])
    
}

extension AccountAbstractedObject {
    static func store(_ value:InputType, in account:Account, context: NSManagedObjectContext) throws {
        if let managedObject = try findMananged(like: value, in: account, context:context) {
            let object = try Self.init(stored: managedObject)
            try object.merge(value)
        }else{
            try insert(value, in: account, context:context)
        }
    }
    
    static func insert(_ remote: InputType, in account: Account, context: NSManagedObjectContext) throws {
        let newObject = try Self.init(remote: remote)
        try newObject.save()
        let context = PersistenceController.shared.newCacheTaskContext()
        try context.performAndWait {
            let accountObj = try account.managedObject(context: context)
            var storedObj = try newObject.managedObject(context: context)
            storedObj.account = accountObj
            try context.save()
        }
    }
    
    static func processObjects(state: String, account: Account, objects: [InputType] ) {
        guard let typeEnum = typeToObjEnum(type: Self.self) else {
            return
        }
        let typedSubject : JMAPSubject<InputType>
        if account.typedSubjects[typeEnum] == nil {
            typedSubject = JMAPSubject<InputType>()
            account.typedSubjects[typeEnum] = typedSubject
        }else{
            typedSubject = account.typedSubjects[typeEnum] as! JMAPSubject<InputType>
        }
        
        if typedSubject.sink == nil {
            typedSubject.sink = typedSubject.subject.sink { completion in
                switch completion {
                case .finished:
                    account.mailboxState = typedSubject.state
                    try? account.updateCD(updateState: true)
                case .failure(let error):
                    print(error)

                }
            } receiveValue: { value in
                do{
                    let context = PersistenceController.shared.newCacheTaskContext()
                    try context.performAndWait {
                        try store(value, in: account, context: context)
                    }
                }catch{
                    print("Error in receiver \(error)")
                }
            }
        }
        
        typedSubject.state = state
        for object in objects {
            typedSubject.subject.send(object)
        }
        if typedSubject.state == state {
            typedSubject.subject.send(completion: .finished)
        }
    }
}

protocol AccountScoped {
    var account: CDAccount? {get set}
}

//workaround as metatypes are not hashable
enum JMAPObjectType {
    case Mailbox
    case Identity
}

extension CoreDataAbstraction {
    func managedObject(context:NSManagedObjectContext) throws -> NSManagedType {
        guard let managedObjectId,
              let object = try context.existingObject(with: managedObjectId) as? NSManagedType else {
            throw PersistenceError.expectedObjectMissing
        }
        return object
    }
    
    static func typeToObjEnum(type: any CoreDataAbstraction.Type) -> JMAPObjectType? {
        switch type{
        case is Mailbox.Type:
            return .Mailbox
        case is EmailIdentity.Type:
            return .Identity
        default:
            return nil
        }
    }
}
