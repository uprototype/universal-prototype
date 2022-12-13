//
//  CoreDataAbstracted.swift
//  uprototype
//
//  Created by Universal on 12/13/22.
//

import CoreData

//behavior of the center object in the relationship
//JMAPObject <> Object <> CDObject
protocol CoreDataAbstraction {
    associatedtype RemoteType
    associatedtype NSManagedType : AccountScoped
    var managedObjectId : NSManagedObjectID? { get }
    
    init(stored: NSManagedType) throws
    init(remote: RemoteType)
    
    func save() throws
    func merge(_ remote: RemoteType) throws
    func managedObject(context:NSManagedObjectContext) throws -> NSManagedType
    
    static func store(_ value:RemoteType, in account:Account, context: NSManagedObjectContext) throws
    static func findMananged(like remote:RemoteType, in account:Account, context: NSManagedObjectContext) throws -> NSManagedType?
    static func insert(_ remote:RemoteType, in account:Account, context: NSManagedObjectContext) throws
    
    static func processObjects(state: String, account: Account, objects: [RemoteType])
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
    static func store(_ value:RemoteType, in account:Account, context: NSManagedObjectContext) throws {
        if let managedObject = try findMananged(like: value, in: account, context:context) {
            let object = try Self.init(stored: managedObject)
            try object.merge(value)
        }else{
            try insert(value, in: account, context:context)
        }
    }
    
    static func insert(_ remote: RemoteType, in account: Account, context: NSManagedObjectContext) throws {
        let newObject = Self.init(remote: remote)
        try newObject.save()
        let context = PersistenceController.shared.newCacheTaskContext()
        try context.performAndWait {
            let accountObj = try account.managedObject(context: context)
            var storedObj = try newObject.managedObject(context: context)
            storedObj.account = accountObj
            try context.save()
        }
        
    }
    
    func managedObject(context:NSManagedObjectContext) throws -> NSManagedType {
        guard let managedObjectId,
              let object = try context.existingObject(with: managedObjectId) as? NSManagedType else {
            throw MailModelError.expectedObjectMissing
        }
        return object
    }
    
    static func processObjects(state: String, account: Account, objects: [RemoteType] ) {
        guard let typeEnum = typeToObjEnum(type: Self.self) else {
            return
        }
        let typedSubject : JMAPSubject<RemoteType>
        if account.typedSubjects[typeEnum] == nil {
            typedSubject = JMAPSubject<RemoteType>()
            account.typedSubjects[typeEnum] = typedSubject
        }else{
            typedSubject = account.typedSubjects[typeEnum] as! JMAPSubject<RemoteType>
        }
        
        if typedSubject.sink == nil {
            typedSubject.sink = typedSubject.subject.sink { completion in
                switch completion {
                case .finished:
                    account.mailboxState = typedSubject.state
                    try? account.updateCD()
                case .failure(let error):
                    print(error)

                }
            } receiveValue: { value in
                do{
                    let context = PersistenceController.shared.newCacheTaskContext()
                    try context.performAndWait {
//                        try T.store(value, in: self, context: context)
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
