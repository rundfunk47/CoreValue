//
//  CoreValueMacTests.swift
//  CoreValueMacTests
//
//  Created by Benedikt Terhechte on 05/07/15.
//  Copyright © 2015 Benedikt Terhechte. All rights reserved.
//

import XCTest
import CoreData

struct Employee : CVManagedStruct {
    static let EntityName = "Employee"
    
    let name: String
    let age: Int16
    let position: String?
    let department: String
    let job: String
    
    init(fromObject object: NSManagedObject) throws {
        name = try object.unbox("name")
        age = try object.unbox("age")
        position = try object.unbox("position")
        department = try object.unbox("department")
        job = try object.unbox("job")
    }
    
    init(name: String, age: Int16, position: String?, department: String, job: String) {
        self.name = name
        self.age = age
        self.position = position
        self.department = department
        self.job = job
    }
}

struct StoredShopEmployee : CVManagedPersistentStruct {
    static let EntityName = "Employee"
    
    var objectID: NSManagedObjectID?
    let name: String
    let age: Int16
    let position: String?
    let department: String
    let job: String
    let shop: StoredShop?
    
    init(fromObject object: NSManagedObject) throws {
        objectID = try object.unbox("objectID")
        name = try object.unbox("name")
        age = try object.unbox("age")
        position = try object.unbox("position")
        department = try object.unbox("department")
        job = try object.unbox("job")
        shop = try object.unbox("shop")
    }
    
    init(objectID: NSManagedObjectID?, name: String, age: Int16, position: String?, department: String, job: String, shop: StoredShop?) {
        self.objectID = objectID
        self.name = name
        self.age = age
        self.position = position
        self.department = department
        self.job = job
        self.shop = shop
    }
}

struct Shop: CVManagedStruct {
    static let EntityName = "Shop"
    
    var name: String
    var owner: Employee
    
    init(fromObject object: NSManagedObject) throws {
        name = try object.unbox("name")
        owner = try object.unbox("owner")
    }
    
    init(name: String, owner: Employee) {
        self.name = name
        self.owner = owner
    }
}

struct Company: CVManagedStruct {
    static let EntityName = "Company"
    
    var name: String
    var employees: Array<Employee>
    
    init(fromObject object: NSManagedObject) throws {
        name = try object.unbox("name")
        employees = try object.unbox("employees")
    }
    
    init(name: String, employees: Array<Employee>) {
        self.name = name
        self.employees = employees
    }
}

struct Other: CVManagedStruct {
    static let EntityName = "Other"
    
    var boolean: Bool
    var data: Data
    var date: Date
    var decimal: NSDecimalNumber
    var double: Double
    var float: Float
    
    init(fromObject object: NSManagedObject) throws {
        boolean = try object.unbox("boolean")
        data = try object.unbox("name")
        date = try object.unbox("date")
        decimal = try object.unbox("decimal")
        double = try object.unbox("double")
        float = try object.unbox("float")
    }
    
    init(boolean: Bool, data: Data, date: Date, decimal: NSDecimalNumber, double: Double, float: Float) {
        self.boolean = boolean
        self.data = data
        self.date = date
        self.decimal = decimal
        self.double = double
        self.float = float
    }
}

struct StoredShop: CVManagedPersistentStruct {
    static let EntityName = "Shop"
    
    var objectID: NSManagedObjectID?
    var name: String
    var owner: Employee
    
    init(fromObject object: NSManagedObject) throws {
        objectID = try object.unbox("objectID")
        name = try object.unbox("name")
        owner = try object.unbox("owner")
    }
    
    init(objectID: NSManagedObjectID?, name: String, owner: Employee) {
        self.objectID = objectID
        self.name = name
        self.owner = owner
    }
}

struct StoredEmployeeShop: CVManagedPersistentStruct {
    static let EntityName = "Shop"
    
    var objectID: NSManagedObjectID?
    var name: String
    var employees: [StoredShopEmployee]
    
    init(fromObject object: NSManagedObject) throws {
        objectID = try object.unbox("objectID")
        name = try object.unbox("name")
        employees = try object.unbox("employees")
    }
    
    init(objectID: NSManagedObjectID?, name: String, employees: [StoredShopEmployee]) {
        self.objectID = objectID
        self.name = name
        self.employees = employees
    }
}

enum CarType:String{
    case Pickup = "pickup"
    case Sedan = "sedan"
    case Hatchback = "hatchback"
}

extension CarType: Boxing,Unboxing {}

struct Car: CVManagedPersistentStruct {
    static let EntityName = "Car"
    var objectID: NSManagedObjectID?
    var name: String
    var type: CarType
    
    init(fromObject object: NSManagedObject) throws {
        objectID = try object.unbox("objectID")
        name = try object.unbox("name")
        type = try object.unbox("type")
    }
    
    init(objectID: NSManagedObjectID?, name: String, type: CarType) {
        self.objectID = objectID
        self.name = name
        self.type = type
    }
}

/// Attempt f, fail test if it throws
func testTry(_ f: () throws -> ()) {
    do {
        try f()
    } catch let error as NSError {
        XCTAssert(false, error.localizedDescription)
    }
}

func setUpInMemoryManagedObjectContext(_ cls: AnyClass) -> NSManagedObjectContext? {
    let b = Bundle(for: cls)
    let modelURL = b.url(forResource: "CoreValueTests", withExtension: "mom")!
    let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)!
    
    let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
    do {
        try persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
    } catch _ {
        return nil
    }

    assert(Thread.isMainThread)
    let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
    
    return managedObjectContext
}


class CoreValueMacTests: XCTestCase {
    
    var context: NSManagedObjectContext = {
        return setUpInMemoryManagedObjectContext(CoreValueMacTests.self)!
    }()
    
    let employee1 = {
        return Employee(name: "John Doe", age: 20, position: "Manager", department: "Flowers", job: "Garden Guy")
    }()
    
    let employee2 = {
        return Employee(name: "Nobody", age: 14, position: nil, department: "Kindergarten", job: "Playing")
    }()
    
    var nsEmployee1: NSManagedObject!
    
    var nsEmployee2: NSManagedObject!
    
    let shop = {
        return Shop(name: "Carl's Household Items", owner: Employee(name: "Carl", age: 66, position: nil, department: "Register", job: "Owner"))
    }()
    
    var nsShop: NSManagedObject!
    
    let company = {
        return Company(name: "Household Wares Inc.", employees: [Employee(name: "Chris High", age: 23, position: nil, department: "Factory", job: "Worker"), Employee(name: "Ben Down", age: 32, position: nil, department: "Factory", job: "Cleaner")])
    }()
    
    var nsCompany: NSManagedObject!
    
    let other = {
        return Other(boolean: true, data: Data(), date: Date(), decimal: NSDecimalNumber(), double: 10, float: 20)
    }()
    
    var nsOther: NSManagedObject!
    
    override func setUp() {
        super.setUp()
        do {
            self.nsEmployee1 = try self.employee1.toObject(self.context)
        }catch CVManagedStructError.structConversionError(let msg) {
            XCTAssert(false, msg)
        } catch CVManagedStructError.structValueError(let msg) {
            XCTAssert(false, msg)
        } catch let e {
            print(e)
            XCTAssert(false, "An Error Occured")
        }
        
        self.nsEmployee2 = try! self.employee2.toObject(self.context)
        do {
            self.nsShop = try self.shop.toObject(self.context)
        } catch CVManagedStructError.structConversionError(let msg) {
            XCTAssert(false, msg)
        } catch CVManagedStructError.structValueError(let msg) {
            XCTAssert(false, msg)
        } catch let e {
            print(e)
            XCTAssert(false, "An Error Occured")
        }
        
        do {
            self.nsCompany = try self.company.toObject(self.context)
        } catch CVManagedStructError.structConversionError(let msg) {
            XCTAssert(false, msg)
        } catch CVManagedStructError.structValueError(let msg) {
            XCTAssert(false, msg)
        } catch let e {
            print(e)
            XCTAssert(false, "An Error Occured")
        }
        
        do {
            self.nsOther = try self.other.toObject(self.context)
        } catch CVManagedStructError.structConversionError(let msg) {
            XCTAssert(false, msg)
        } catch CVManagedStructError.structValueError(let msg) {
            XCTAssert(false, msg)
        } catch let e {
            print(e)
            XCTAssert(false, "An Error Occured")
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testToCoreDataNonNil() {
        do {
            let cd = try self.employee1.toObject(self.context)
            if (cd.value(forKey: "name") as! String) != self.employee1.name {
                XCTAssert(false, "Conversion failed: name")
            }
            if (cd.value(forKey: "age") as! NSNumber).intValue != Int(self.employee1.age) {
                XCTAssert(false, "Conversion failed: age")
            }
        } catch CVManagedStructError.structConversionError(let msg) {
            XCTAssert(false, msg)
        } catch CVManagedStructError.structValueError(let msg) {
            XCTAssert(false, msg)
        } catch let e {
            print(e)
            XCTAssert(false, "An Error Occured")
        }
    }
    
    func testToCoreDataNil() {
        do {
            let cd = try self.employee2.toObject(self.context)
            if (cd.value(forKey: "name") as! String) != self.employee2.name {
                XCTAssert(false, "Conversion failed: name")
            }
            if (cd.value(forKey: "age") as! NSNumber).intValue != Int(self.employee2.age) {
                XCTAssert(false, "Conversion failed: age")
            }
            if (cd.value(forKey: "position") != nil) {
                XCTAssert(false, "Conversion failed: age")
            }
        } catch CVManagedStructError.structConversionError(let msg) {
            XCTAssert(false, msg)
        } catch CVManagedStructError.structValueError(let msg) {
            XCTAssert(false, msg)
        } catch let e {
            print(e)
            XCTAssert(false, "An Error Occured")
        }
    }
    
    func testFromCoreDataNonNil() {
        testTry {
            let t = try Employee(fromObject: self.nsEmployee1)
            if t.name != self.employee1.name ||
                t.age != self.employee1.age {
                    XCTAssert(false, "Conversion Error")
            }
        }
    }
    
    func testFromCoreDataNil() {
        testTry {
            let t = try Employee(fromObject: self.nsEmployee2)
            if t.name != self.employee2.name ||
                t.age != self.employee2.age ||
                t.position != nil {
                    XCTAssert(false, "Conversion Error")
            }
        }
    }
    
    func testToCoreDataSub() {
        do {
            let cd = try self.shop.toObject(self.context)
            if (cd.value(forKey: "name") as! String) != self.shop.name {
                XCTAssert(false, "Conversion failed: name")
            }
            let owner = cd.value(forKey: "owner") as! NSManagedObject
            if (owner.value(forKey: "name") as! String != self.shop.owner.name) {
                XCTAssert(false, "Conversion failed: owner's name")
            }
        } catch CVManagedStructError.structConversionError(let msg) {
            XCTAssert(false, msg)
        } catch CVManagedStructError.structValueError(let msg) {
            XCTAssert(false, msg)
        } catch let e {
            print(e)
            XCTAssert(false, "An Error Occured")
        }
    }
    
    func testFromCoreDataSub() {
        testTry {
            let t = try Shop(fromObject: self.nsShop)
            if t.name != self.shop.name ||
                t.owner.name != self.shop.owner.name {
                    XCTAssert(false, "Conversion Error")
            }
        }
    }
    
    func testToCoreDataSubArray() {
        do {
            let cd = try self.company.toObject(self.context)
            if (cd.value(forKey: "name") as! String) != self.company.name {
                XCTAssert(false, "Conversion failed: name")
            }
            let employees = cd.value(forKey: "employees") as! NSOrderedSet
            if (((employees.firstObject! as! NSManagedObject).value(forKey: "name") as! String) != self.company.employees[0].name) {
                XCTAssert(false, "Conversion failed: employee's name")
            }
            if (((employees.lastObject! as! NSManagedObject).value(forKey: "name") as! String) != self.company.employees.last?.name) {
                XCTAssert(false, "Conversion failed: employee's order")
            }
            if let ab:NSOrderedSet = cd.value(forKey: "employees") as? NSOrderedSet {
                if ab.count != self.company.employees.count {
                    XCTAssert(false, "Did not box all employees")
                }
            }
        } catch CVManagedStructError.structConversionError(let msg) {
            XCTAssert(false, msg)
        } catch CVManagedStructError.structValueError(let msg) {
            XCTAssert(false, msg)
        } catch let e {
            print(e)
            XCTAssert(false, "An Error Occured")
        }
    }
    
    func testFromCoreDataSubArray() {
        testTry {
            let t = try Company(fromObject: self.nsCompany)
            if t.name != self.company.name ||
                t.employees[0].name != self.company.employees[0].name {
                    XCTAssert(false, "Conversion Error")
            }
            if t.employees.count != self.company.employees.count {
                XCTAssert(false, "Wrong amount of employees")
            }
            if t.employees.last?.name != self.company.employees.last?.name {
                XCTAssert(false, "Wrong Employee order")
            }
        }
    }
    
    func testOtherDataTypesToCoreData() {
        do {
            let cd = try self.other.toObject(self.context)
            
            if (cd.value(forKey: "boolean") as! NSNumber).boolValue != self.other.boolean {
                XCTAssert(false, "Conversion failed: boolean")
            }
            
            guard cd.value(forKey: "data") is NSData else {
                XCTAssert(false, "Conversion failed: nsdata")
                return
            }
            
            guard cd.value(forKey: "date") is NSDate else {
                XCTAssert(false, "Conversion failed: nsdate")
                return
            }
            
            guard cd.value(forKey: "decimal") is NSDecimalNumber else {
                XCTAssert(false, "Conversion failed: decimal")
                return
            }
            
            guard cd.value(forKey: "double") is NSNumber else {
                XCTAssert(false, "Conversion failed: double")
                return
            }
            
        } catch CVManagedStructError.structConversionError(let msg) {
            XCTAssert(false, msg)
        } catch CVManagedStructError.structValueError(let msg) {
            XCTAssert(false, msg)
        } catch let e {
            print(e)
            XCTAssert(false, "An Error Occured")
        }
    }
    
    func testRawRepresentableToCoreData() {
        let car1 = Car(objectID: nil, name: "Super Sedan", type: .Sedan)
        do {
           let cd = try car1.toObject(context)
            if (cd.value(forKey: "type") as! String) != CarType.Sedan.rawValue {
                XCTAssert(false, "Boxing failed: Raw Represantable String")
            }
            
            let obj:Car = try Car.unbox(cd)
            
            if (obj.type != .Sedan) {
                XCTAssert(false, "Unboxing failed: Raw Represantable String")
            }
            
        } catch let e {
            XCTAssert(false, "\(e)")
        }
    }
}


class CoreValueQueryTests: XCTestCase {
    
    var context: NSManagedObjectContext = {
        return setUpInMemoryManagedObjectContext(CoreValueMacTests.self)!
    }()
    
    var manyEmployees: [NSManagedObject] = []
    
    override func setUp() {
        super.setUp()
        for n in 0..<50 {
            let employee = Employee(name: "employee \(n)", age: n + 10, position: nil, department: "", job: "")
            do {
                manyEmployees.append(try employee.toObject(self.context))
            } catch let e {
                print(e)
                XCTAssert(false, "An Error Occured")
            }
        }
    }
    
    func testQueryYoungOnes() {
        // Important, the results: [Employee] is required for the type checker to figure things out
        testTry {
            let predicate = NSPredicate(format: "age > 10 and age < 12", argumentArray: nil)
            let results: [Employee] = try Employee.query(self.context, predicate: predicate) 
            if results.count != 1 {
                XCTAssert(false, "Wrong amount for you ones \(results.count)")
            }
        }
    }
    
    func testQueryOldOnes() {
        testTry {
            let predicate = NSPredicate(format: "age > 50", argumentArray: nil)
            // Important, the results: [Employee] is required for the type checker to figure things out
            let results: [Employee] = try Employee.query(self.context, predicate: predicate)
            if results.count != 9 {
                XCTAssert(false, "Wrong amount for old ones \(results.count)")
            }
        }
    }
    
    func testQueryOrder() {
        // Important, the results: [Employee] is required for the type checker to figure things out
        let descriptors: [NSSortDescriptor] = [NSSortDescriptor(key: "age", ascending: false)]
        testTry {
            let results: [Employee] = try Employee.query(self.context, predicate: nil, sortDescriptors: descriptors)
            if let r = results.first {
                if r.age != 59 {
                    XCTAssert(false, "wrong employee age: \(r.age)")
                }
            } else {
                XCTAssert(false, "Wrong query amount result: 0")
            }
        }
    }
    
    func testStorage() {
        // test whether storing / updating works properly
        
        // create two shops
        var s1 = StoredShop(objectID: nil, name: "shop1", owner: Employee(name: "a", age: 4, position: nil, department: "", job: ""))
        do {
            let _ = try s1.mutatingToObject(self.context)
        } catch let e {
            XCTAssert(false, "\(e)")
        }
        
        var s2 = StoredShop(objectID: nil, name: "shop2", owner: Employee(name: "a", age: 4, position: nil, department: "", job: ""))
        testTry {
            let _ = try s2.mutatingToObject(self.context)
        }
        
        // now update both shops
        testTry {
            let _ = try s1.mutatingToObject(self.context)
        }
        
        testTry {
            let _ = try s2.mutatingToObject(self.context)
        }
        
        // And query the count
        testTry {
            let predicate = NSPredicate(format: "self.name=='shop1'", argumentArray: [])
            let results: [StoredShop] = try StoredShop.query(self.context, predicate: predicate)
            XCTAssert(results.count == 1, "Wrong amount of objects, update did insert: \(results.count)")
        }
    }
    
    func testDeletion() {
        // create two shops
        var s1 = StoredShop(objectID: nil, name: "shop1", owner: Employee(name: "a", age: 4, position: nil, department: "", job: ""))
        testTry {
            try s1.save(self.context)
        }
        
        var s2 = StoredShop(objectID: nil, name: "shop2", owner: Employee(name: "a", age: 4, position: nil, department: "", job: ""))
        testTry {
            try s2.save(self.context)
        }
        
        // delete one
        testTry {
            let _ = try s2.delete(self.context)
        }
        
        // and count
        testTry {
            let results: [StoredShop] = try StoredShop.query(self.context, predicate: nil)
            XCTAssert(results.count == 1, "Failed to delete object \(s2) from context")
        }
    }
    
    func testInfiniteLoop() {
        let employee = StoredShopEmployee(objectID: nil, name: "John Doe", age: 18, position: "Clerk", department: "Carpet", job: "Cleaner", shop:nil)
        var shop = StoredEmployeeShop(objectID: nil, name: "Carpet shop", employees: [employee])
        
        try! shop.save(context)
        //Will crash in infinite loop
        let shops:[StoredEmployeeShop] = try! StoredEmployeeShop.query(context, predicate: nil)
        print(shops)
        XCTAssertNotNil(shops)
    }
}


class CoreValuePerformanceTests: XCTestCase {
    
    var context: NSManagedObjectContext = {
        return setUpInMemoryManagedObjectContext(CoreValueMacTests.self)!
    }()
    
    var manyCompanies: [Company] = {
        var box: [Employee] = []
        for c in 0..<25 {
            box.append(Employee(name: "employee", age: Int16(c), position: nil, department: "", job: ""))
        }
        var companyBox: [Company] = []
        for c in 0..<50 {
            companyBox.append(Company(name: "a Company \(c)", employees: box))
        }
        return companyBox
    }()
    
    func testUnboxPerformance() {
        self.measure {
            testTry {
                let results: [NSManagedObject] = try self.manyCompanies.map { company in
                    let managedCompany = try company.toObject(self.context)
                    XCTAssert(managedCompany.value(forKey: "name") as? String == company.name)
                    return managedCompany
                }
                XCTAssert(results.count == self.manyCompanies.count, "Unboxed Companies have to be the same amount of entities")
            }
        }
    }
    
    func testBoxPerformance() {
        testTry {
            let results: [NSManagedObject] = try manyCompanies.map { company in
                let managedCompany = try company.toObject(self.context)
                XCTAssert(managedCompany.value(forKey: "name") as? String == company.name)
                return managedCompany
            }

            self.measure {
                testTry {
                    let entities = try results.map {
                        try Company(fromObject: $0)
                    }

                    XCTAssert(entities.count == results.count, "Boxed Companies have to have the same amount of entities.")
                }
            }
        }
    }
}



