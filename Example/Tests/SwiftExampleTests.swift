//
//  SwiftExampleTests.swift
//  L360ContextWatcher
//
//  Created by Yusuf Sobh on 7/8/16.
//  Copyright © 2016 Yusuf Sobh. All rights reserved.
//

@testable import L360ContextWatcher
import XCTest
import CoreData

class SwiftExampleTests: XCTestCase {
    
    var context:NSManagedObjectContext =  NSManagedObjectContext()
    var changesContext:NSManagedObjectContext = NSManagedObjectContext()

    override func setUp() {
        let bundle = NSBundle(identifier: "org.cocoapods.demo.L360ContextWatcher-Tests")
        let url = bundle?.URLForResource("Model", withExtension: "momd")
        let managedObjectModel = NSManagedObjectModel(contentsOfURL: url!)
        
        let coordinater:NSPersistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel!)
        
        do {
            try coordinater.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil)
        } catch {
            XCTFail("Failed to setup core data")
        }
        
        self.context = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
        self.context.persistentStoreCoordinator = coordinater
        
        
        self.changesContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
        self.changesContext.persistentStoreCoordinator = coordinater
        
        L360ContextWatcher.registerForContextChangeNotificationsInContext(self.context, callbackContext: self.changesContext, andReturnType: L360ContextWatcherReturnType.ManagedObjects)
        
        super.setUp()
    }
    
    override func tearDown() {
        L360ContextWatcher.unregisterObserver(self)
        super.tearDown()
    }
    
    func testSwiftInsertDog() {
        let exp = self.expectationWithDescription("insert")
        
        L360ContextWatcher.registerObserver(self, changeType: .Insert, entityClass: Dog.self, filterPredicate: nil)  { (objects:[NSManagedObject]?) in
            if let insertedDog = objects?.first as? Dog {
                XCTAssertEqual(insertedDog.name, "Lucky")
                exp.fulfill()
            }
        }
        
        // Insert the dog
        self.context.performBlock {
            let dog:Dog = NSEntityDescription.insertNewObjectForEntityForName("Dog", inManagedObjectContext: self.context) as! Dog
            dog.name = "Lucky"
            
            do {
                try self.context.save()
            } catch {
                XCTFail("Failed to save context")
            }
        }
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
        
    }
    
}
