//
//  CoreValue.swift
//  CoreValue
//
//  Created by Benedikt Terhechte on 05/07/15.
//  Copyright © 2015 Benedikt Terhechte. All rights reserved.
//

import Foundation
import CoreData

// MARK: Unboxing

public let CVErrorDomain = "CVErrorDomain"
public let CVErrorUnboxFailed = 1

internal extension NSError {
    convenience init(unboxErrorMessage: String) {
        self.init(domain: CVErrorDomain, code: CVErrorUnboxFailed, userInfo: [NSLocalizedDescriptionKey: unboxErrorMessage])
    }
}

/**
Unboxing NSManagedObjects into Value types.

- Unboxing can fail, so the unboxed value is an either type that explains the error via TypeMismatch
- Unboxing defines the 'Unboxing' protocol which a type has to conform to in order to be able
  to be unboxed
*/

extension NSManagedObject {
    public func unbox<A>(_ key: String) throws -> A where A: Unboxing, A == A.StructureType {
        if let s = self.value(forKey: key) {
            return try A.unbox(s as AnyObject)
        }
        throw NSError(unboxErrorMessage: "\(key) \(A.self)")
    }
    
    public func unbox<A>(_ key: String) throws -> A? where A: Unboxing, A == A.StructureType {
        do {
            let value = try self.unbox(key) as A
            return value
        } catch {
            return nil
        }
    }
    
    public func unbox<A>(_ key: String) throws -> [A] where A: Unboxing, A == A.StructureType {
        if let s = self.value(forKey: key) {
            return try Array<A>.unbox(s as AnyObject)
        } else {
            throw NSError(unboxErrorMessage: "\(key) \(A.self)")
        }
    }
}

/**
Each Unboxing operation returns this either type which allows unboxing to fail
if the NSManagedObject does not offer the correct values / datatypes for the
Value type that is to be constructed.

- parameter T: is the value type that we're trying to construct.
*/
public enum Unboxed<T> {
    case success(T)
    case typeMismatch(String)
    
    public var value: T? {
        switch self {
        case let .success(value): return value
        default: return .none
        }
    }
}

/**
The *Unboxing* protocol
The *unbox* function recieves a Core Data object and returns an unboxed value type. This value type
is defined by the StructureType typealias
*/
public protocol Unboxing {
    associatedtype StructureType = Self
    /**
    Unbox a data from an NSManagedObject instance (or the instance itself) into a value type
    - parameter value: The data to be unboxed into a value type
    */
    static func unbox(_ value: AnyObject) throws -> StructureType
}

// MARK: -
// MARK: Boxing

/**
Boxing value types into NSManagedObject instances

- Boxing can fail if the value type in question is not supported (i.e. enum) or doesn't conform to the Boxing
  protocol
- Boxing requires the name of the entity that the boxed NSManagedObject maps to. It would be possible
  to just use the value type's name (i.e. struct Employee) but I decided against it to give the user
  more control over this
*/

public protocol Boxing {
    /** Box Self into the given managed object with key *withKey*
    - parameter object: The NSManagedObject that the value type self should be boxed into
    - parameter withKey: The name of the property in the NSManagedObject that it should be written to
    */
    func box(_ object: NSManagedObject, withKey: String) throws
}

public protocol BoxingStruct : Boxing {
    
    /** The name of the Core Data entity that the boxed value type should become */
    static var EntityName: String {get}
    
    /**
    Convert the current UnboxingStruct instance to a NSManagedObject
    throws 'CVManagedStructError' if the process fails.
    
    The implementation for this is included via an extension (see below)
    it uses reflection to automatically convert this
    
    - parameter context: An Optional NSManagedObjectContext. If it is not provided, the objects
    are only temporary.
    */
    func toObject(_ context: NSManagedObjectContext?) throws -> NSManagedObject
}

extension BoxingStruct {
    public func box(_ object: NSManagedObject, withKey: String) throws {
        try object.setValue(self.toObject(object.managedObjectContext), forKey: withKey)
    }
}

/**
   Add support for persistence, i.e. entities that know they were fetched from a context
   and can appropriately update themselves in the context, or be deleted, etc.
   Still a basic implementation.

   Caveats:
   - If type T: BoxingPersistentStruct has a property Tx: BoxingStruct, then saving/boxing
     T will create new instances of Tx. So, as a requirement that is with the current swift compiler
     impossible to define in types, any property on BoxingPersistentStruct also has to be of
     type BoxingPersistentStruct
*/

public protocol BoxingPersistentStruct : BoxingStruct {
    /** If this value type is based on an existing object, this is the object id, so we can
        locate it and update it in the  managedobjectstore instead of re-inserting it*/
    var objectID: NSManagedObjectID? {get set}
    
    /** Persistent structs update their objectID when saving. This means that the toObject
        call needs to be mutating. Calling simply toObject will also work, but will fail
        to update the objectID, thus causing multiple insertions (into the context) of the 
        same object during update */
    mutating func mutatingToObject(_ context: NSManagedObjectContext?) throws -> NSManagedObject
    
    /** Delete an object from the managedObjectStore. Has the side effect of setting the
        objectID of the BoxingPersistentStruct instance to nil. Will do nothing if there
        is no objectID (but return false)
    
        Throws an instance of CVManagedStructError in case the object cannot be found
        in the managedObjectStore or if deletion fails due to an underlying core data
        error.

        - returns: Bool True if an object was successfully deleted, false if not
   */
    mutating func delete(_ context: NSManagedObjectContext?) throws -> Bool
    
    /** Save an object to the managedObjectStore or update the current instance in the
        managedObjectStore with the current Value Type properties.
        Throws CVManagedStructErorr if saving fails */
    mutating func save(_ context: NSManagedObjectContext) throws
}

public protocol UnboxingStruct : Unboxing {
    /** 
    Call on any UnboxingStruct supporting object to create a self instance from a
    NSManagedObject. 
    
    The fromObject implementation can be implemented with custom operators
    to quickly map the object properties onto the required types (see examples)
    
    - parameter object: The NSManagedObject that should be converted to an instance of self
    */
    init(fromObject object: NSManagedObject) throws
}

extension UnboxingStruct {
    public static func unbox<A: UnboxingStruct>(_ value: AnyObject) throws -> A where A == A.StructureType {
        switch value {
            case let object as NSManagedObject:
                return try A(fromObject: object)
        default:
            throw NSError(unboxErrorMessage: "\(value) is not NSManagedObject")
        }
    }
}

// MARK: -
// MARK: CVManagedStruct

/**
Type aliases for boxing/unboxing support, and the same for persistence

Note: In Swift2 b6 the 'StructureType' information seems to get lost when
using the protocol<> type. In order to prevent that, I'm re-inserting them here.
Temporarily.
An alternative would be not using the protocol<> but instead

protocol CVManagedStruct : BoxingStruct, UnboxingStruct {
    typealias StructureType = Self
}

*/
public typealias _CVManagedStruct = BoxingStruct & UnboxingStruct

public protocol CVManagedStruct : _CVManagedStruct {
    associatedtype StructureType = Self
}

public typealias _CVManagedPersistentStruct = BoxingPersistentStruct & UnboxingStruct

public protocol CVManagedPersistentStruct : _CVManagedPersistentStruct {
    associatedtype StructureType = Self
}

// MARK: Querying

/**
BoxingStruct extensions for querying CoreData with predicates

- There's certainly a lot of low hanging fruit here to be implemented, such as a better way of querying, 
  i.e. a more type safe NSPredicate
- Or a more type safe way of describing order.

For a first release, this should do though.
*/
extension BoxingStruct {
    
    public static func query<T: UnboxingStruct>(_ context: NSManagedObjectContext,
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]? = nil) throws -> Array<T> {
            
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: self.EntityName)
            
            if let sortDescriptors = sortDescriptors {
                fetchRequest.sortDescriptors = sortDescriptors
            }
            
            // We need to process (i.e. convert) all objects at once, so there shouldn't
            // be any faults.
            fetchRequest.returnsObjectsAsFaults = false
            
            fetchRequest.predicate = predicate
            
            let fetchResults = try context.fetch(fetchRequest)
            return try fetchResults.map { obj in
                try T(fromObject: obj)
            }
    }

}

// MARK: -
// MARK: Type Extensions

// Extending existing value types to support Boxing and Unboxing
// For all types that core data supports

/**
NSManagedObject already contains implementations for unbox and box
*/
extension NSManagedObject: Unboxing, Boxing {
    public static func unbox(_ value: AnyObject) -> NSManagedObject {
        return value as! NSManagedObject
    }
    public func box(_ object: NSManagedObject, withKey: String) throws {
        object.setValue(self, forKey: withKey)
    }
}

extension NSManagedObjectID: Unboxing, Boxing {
    public static func unbox(_ value: AnyObject) -> NSManagedObjectID {
        return value as! NSManagedObjectID
    }
    public func box(_ object: NSManagedObject, withKey: String) throws {
        object.setValue(self, forKey: withKey)
    }
}

/**
Arrays cannot implement the Unboxing protocol because they do not contain a 
one to one mapping of the type T1 input to the type T2 output. Instead, they map
from T1 input to [T2] output. In order to get the type checker to understand this,
we can informally support the unboxing protocol by explaining the types in terms of
type constraints. 

- Currently, there's no support for NSSet
*/
extension Array {
    public static func unbox<T: Unboxing>(_ value: AnyObject) throws -> [T] where T == T.StructureType {
        switch value {
        case let orderedSet as NSOrderedSet:
            return try orderedSet.map { try T.unbox($0 as AnyObject) }
        default:
            throw NSError(unboxErrorMessage: "Array")
        }
    }
}

extension Int: Unboxing, Boxing {
    public static func unbox(_ value: AnyObject) throws -> Int {
        switch value {
        case let v as Int:
            return v
        default:
            throw NSError(unboxErrorMessage: "Int")
        }
    }
    public func box(_ object: NSManagedObject, withKey: String) throws {
        object.setValue(self, forKey: withKey)
    }
}

extension Int16: Unboxing, Boxing {
    public static func unbox(_ value: AnyObject) throws -> Int16 {
        switch value {
        case let v as NSNumber:
            return v.int16Value
        default:
            throw NSError(unboxErrorMessage: "Int16")
        }
    }
    public func box(_ object: NSManagedObject, withKey: String) throws {
        object.setValue(NSNumber(value: self as Int16), forKey: withKey)
    }
}

extension Int32: Unboxing, Boxing {
    public static func unbox(_ value: AnyObject) throws -> Int32 {
        switch value {
        case let v as NSNumber:
            return v.int32Value
        default:
            throw NSError(unboxErrorMessage: "Int32")
        }
    }
    public func box(_ object: NSManagedObject, withKey: String) throws {
        object.setValue(NSNumber(value: self as Int32), forKey: withKey)
    }
}

extension Int64: Unboxing, Boxing {
    public static func unbox(_ value: AnyObject) throws -> Int64 {
        switch value {
        case let v as NSNumber:
            return v.int64Value
        default:
            throw NSError(unboxErrorMessage: "Int64")
        }
    }
    public func box(_ object: NSManagedObject, withKey: String) throws {
        object.setValue(NSNumber(value: self as Int64), forKey: withKey)
    }
}

extension Double: Unboxing, Boxing {
    public static func unbox(_ value: AnyObject) throws -> Double {
        switch value {
        case let v as NSNumber:
            return v.doubleValue
        default:
            throw NSError(unboxErrorMessage: "Double")
        }
    }
    public func box(_ object: NSManagedObject, withKey: String) throws {
        object.setValue(NSNumber(value: self as Double), forKey: withKey)
    }
}

extension Float: Unboxing, Boxing {
    public static func unbox(_ value: AnyObject) throws -> Float {
        switch value {
        case let v as NSNumber: return v.floatValue
        default: throw NSError(unboxErrorMessage: "Float")
        }
    }
    public func box(_ object: NSManagedObject, withKey: String) throws {
        object.setValue(NSNumber(value: self as Float), forKey: withKey)
    }
}

extension Bool: Unboxing, Boxing {
    public static func unbox(_ value: AnyObject) throws -> Bool {
        switch value {
        case let v as NSNumber: return v.boolValue
        default: throw NSError(unboxErrorMessage: "Boolean")
        }
    }
    public func box(_ object: NSManagedObject, withKey: String) throws {
        object.setValue(NSNumber(value: self as Bool), forKey: withKey)
    }
}

extension String: Unboxing, Boxing {
    public static func unbox(_ value: AnyObject) throws -> String {
        switch value {
        case let v as String: return v
        default: throw NSError(unboxErrorMessage: "String")
        }
    }
    public func box(_ object: NSManagedObject, withKey: String) throws {
        object.setValue(self, forKey: withKey)
    }
}

extension Data: Unboxing, Boxing {
    public static func unbox(_ value: AnyObject) throws -> Data {
        switch value {
        case let data as Data:
            return data
        default:
            throw NSError(unboxErrorMessage: "NSData")
        }
    }
    public func box(_ object: NSManagedObject, withKey: String) throws {
        object.setValue(self, forKey: withKey)
    }
}

extension Date: Unboxing, Boxing {
    public static func unbox(_ value: AnyObject) throws -> Date {
        switch value {
        case let date as Date:
            return date
        default:
            throw NSError(unboxErrorMessage: "NSDate")
        }
    }
    public func box(_ object: NSManagedObject, withKey: String) throws {
        object.setValue(self, forKey: withKey)
    }
}

extension NSDecimalNumber: Unboxing, Boxing {
    public static func unbox(_ value: AnyObject) throws -> NSDecimalNumber {
        switch value {
        case let number as NSDecimalNumber:
            return number
        default:
            throw NSError(unboxErrorMessage: "NSDecimalNumber")
        }
    }
    public func box(_ object: NSManagedObject, withKey: String) throws {
        object.setValue(self, forKey: withKey)
    }
}

public extension Boxing where Self: RawRepresentable, Self.RawValue :Boxing {
    func box(_ object: NSManagedObject, withKey: String) throws {
        return try self.rawValue.box(object, withKey: withKey)
    }
}

public extension Unboxing where Self.StructureType == Self, Self: RawRepresentable, Self.RawValue: Unboxing {
    static func unbox(_ value: AnyObject) throws -> StructureType {
        let rawValue = try Self.RawValue.unbox(value)
        if let r = rawValue as? Self.RawValue, let enumValue = self.init(rawValue: r) {
            return enumValue
        }
        
        throw NSError(unboxErrorMessage: "\(type(of: self))")
    }
}

// MARK: -
// MARK: Reflection Support

/**
This error will be thrown if boxing fails because the core data model
does not know or support the requested property
*/
public enum CVManagedStructError : Error {
    case structConversionError(message: String)
    case structValueError(message: String)
    case structUpdateError(message: String)
    case structDeleteError(message: String)
}

/**
Extend *Boxing* with code that utilizes reflection to convert a value type into an
NSManagedObject
*/

private func virginObjectForEntity(_ entity: String, context: NSManagedObjectContext?) -> NSManagedObject {
    let desc = NSEntityDescription.entity(forEntityName: entity, in:(context ?? nil)!)
    guard let _ = desc else {
        fatalError("entity \(entity) not found in Core Data Model")
    }
    
    return NSManagedObject(entity: desc!, insertInto: context)
}

private extension BoxingStruct {
    func managedObject(_ context: NSManagedObjectContext?) throws -> NSManagedObject {
        return virginObjectForEntity(type(of: self).EntityName, context: context)
    }
}

private extension BoxingPersistentStruct {
    func managedObject(_ context: NSManagedObjectContext?) throws -> NSManagedObject {
        if let objectID = self.objectID,
           let ctx = context {
            do {
                return try ctx.existingObject(with: objectID)
            } catch let error {
                // In this case, we don't want to just insert a new object,
                // instead we should tell the user about this issue.
                throw CVManagedStructError.structUpdateError(message: "Could not fetch object \(self) for id \(objectID): \(error)")
            }
        } else {
            return virginObjectForEntity(type(of: self).EntityName, context: context)
        }
    }
}

public extension BoxingStruct {
    func toObject(_ context: NSManagedObjectContext?) throws -> NSManagedObject {
        let result = try self.managedObject(context)
        
        return try internalToObject(context, result: result, entity: self)
    }
}

public extension BoxingPersistentStruct {
    mutating func mutatingToObject(_ context: NSManagedObjectContext?) throws -> NSManagedObject {
        
        // Only create an entity, if it doesn't exist yet, otherwise update it
        // We can detect existing entities via the objectID property that is part of UnboxingStruct
        var result = try self.managedObject(context)
        
        result = try internalToObject(context, result: result, entity: self)
        if let ctx = context {
            try ctx.save()
            // if it succeeded, update the objectID
            self.objectID = result.objectID
        }
        return result
    }
    
    mutating func delete(_ context: NSManagedObjectContext?) throws -> Bool {
        guard let ctx = context, let oid = self.objectID else { return false }
        
        do {
            let object = try ctx.existingObject(with: oid)
            ctx.delete(object)
            //Commit changes to remove object from the uniquing tables
            try ctx.save()
            
        } catch let error {
            throw CVManagedStructError.structDeleteError(message: "Could not locate object \(oid) in context \(context): \(error)")
        }
        
        return true
    }

    /**
     Default implementation of save function since Swift Structs can't have inheritance.
     */
    mutating func defaultSave(_ context: NSManagedObjectContext) throws {
        let _ = try self.mutatingToObject(context)
    }

    /**
     Point to override when saving nested collection, call .defaultSave method to perform original saving.
     
     Example:
        mutating func save(context: NSManagedObjectContext) throws {
            try self.someArray.saveAll(context)
            try self.defaultSave(context)
        }
     */
    mutating func save(_ context: NSManagedObjectContext) throws {
        try self.defaultSave(context)
    }
}

public extension Array where Element: BoxingPersistentStruct {
    /**
     Saves all persistant structs to context
     */
    mutating func saveAll(_ context: NSManagedObjectContext) throws {
        for (idx, _) in enumerated() {
            try self[idx].save(context)
        }
     }
}

private func internalToObject<T: BoxingStruct>(_ context: NSManagedObjectContext?, result: NSManagedObject, entity: T) throws -> NSManagedObject {
    
    let mirror = Mirror(reflecting: entity)
    
    if let style = mirror.displayStyle , style == .struct {
        
        for (labelMaybe, valueMaybe) in mirror.children {
            
            guard let label = labelMaybe else {
                continue
            }
            
            // We don't want to assign the objectID here
            if ["objectID"].contains(label) {
                continue
            }
            
            // If the value itself conforms to Boxing, we can just box it
            if let value = valueMaybe as? Boxing {
                try value.box(result, withKey: label)
            } else {
                // If this is a sequence type (optional or collection)
                // We have to have a look at the values to see if they conform to boxing
                // The alternative, constraining the type checker a la (roughly)
                // extension Array<T where Generator.Element==Boxing> : Boxing
                // extension Optional<T where Generator.Element==Boxing> : Boxing
                // doesn't currently work with Swift 2
                let valueMirror: Mirror = Mirror(reflecting: valueMaybe)
                
                // We map the display style as well as the optional firt child,
                switch (valueMirror.displayStyle, valueMirror.children.first) {
                    // Empty Optional
                case (.optional?, nil):
                    result.setValue(nil, forKey: label)
                    // Optional with Value
                case (.optional?, let child?):
                    result.setValue(child.value, forKey: label)
                    // A collection of objects
                case (.collection?, _):
                    var objects: [NSManagedObject] = []
                    for (_, value) in valueMirror.children {
                        if let boxedValue = value as? BoxingStruct {
                            objects.append(try boxedValue.toObject(context))
                        }
                    }

                    let orderedSet = NSOrderedSet(array: objects)
                    
                    let mutableValue = result.mutableOrderedSetValue(forKey: label)
                    if objects.count == 0 {
                        mutableValue.removeAllObjects()
                    } else {
                        mutableValue.intersect(orderedSet) // removes objects that are not in new array
                        mutableValue.union(orderedSet) // adds new objects
                    }

                default:
                    // If we end up here, we were unable to decode it
                    throw CVManagedStructError.structValueError(message: "Could not decode value for field '\(label)' obj \(valueMaybe)")
                }
            }
        }
        
        return result
    }
    throw CVManagedStructError.structConversionError(message: "Object is not a struct: \(entity)")
}

