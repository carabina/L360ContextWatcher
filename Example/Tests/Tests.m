//
//  L360ContextWatcherTests.m
//  L360ContextWatcherTests
//
//  Created by Yusuf Sobh on 06/19/2016.
//  Copyright (c) 2016 Yusuf Sobh. All rights reserved.
//

@import XCTest;
@import L360ContextWatcher;
#import <L360ContextWatcher/L360ContextWatcher.h>
#import <CoreData/CoreData.h>
#import "Dog.h"

@interface Tests : XCTestCase

@property (nonatomic, strong) NSManagedObjectContext *context;
@property (nonatomic, strong) NSManagedObjectContext *changesContext;

@end

@implementation Tests

- (void)setUp
{
    // ObjectModel from any models in app bundle
    NSBundle *bundle = [NSBundle bundleWithIdentifier:@"org.cocoapods.demo.L360ContextWatcher-Tests"];
    NSURL *url = [bundle URLForResource:@"Model" withExtension:@"momd"];
    NSManagedObjectModel *managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    
    // Coordinator with in-mem store type
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];
    [coordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:nil];
    
    // Context with private queue
    self.context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.context.persistentStoreCoordinator = coordinator;
    
    self.changesContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    self.changesContext.persistentStoreCoordinator = coordinator;
    
    [L360ContextWatcher registerForContextChangeNotificationsInContext:self.context callbackContext:self.changesContext andReturnType:L360ContextWatcherReturnTypeManagedObjects];
    
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Grab a strong reference to the context watcher queue
    NSOperationQueue *contextWatcherQueue = [L360ContextWatcher sharedInstance].contextWatcherOperationQueue;
    
    // Keep running code until context watcher completely finishes processing
    // so we don't accidently tear down the test while context watcher is processing
    spinRunUntilBlock(^BOOL() {
        return contextWatcherQueue.operationCount == 0;
    });

    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [L360ContextWatcher unregisterObserver:self];
    [super tearDown];
}

typedef BOOL(^evaluationBlock)();

static void (^spinRunUntilBlock)(evaluationBlock) = ^void(evaluationBlock evalBlock){
    NSDate * const end = [[NSDate date] dateByAddingTimeInterval:100];
    
    __block BOOL didComplete = NO;
    
    while ((! didComplete) && (0. < [end timeIntervalSinceNow])) {
        if(evalBlock()) {
            didComplete = YES;
        } else if (! [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.002]]) {
            [NSThread sleepForTimeInterval:0.002];
        }
    }
    
};

// We cannot use waitForExpecation because we need to continue processing blocks on the main queue.
- (BOOL)waitFor:(BOOL *)flag timeout:(NSTimeInterval)timeoutSecs {
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeoutSecs];
    
    do {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeoutDate];
        if ([timeoutDate timeIntervalSinceNow] < 0.0) {
            break;
        }
    }
    while (!*flag);
    return *flag;
}

- (void)testInsertedDog
{
    __block BOOL done = NO;
    
    // First setup your observer with context watcher
    [L360ContextWatcher registerObserver:self changeType:L360ContextChangeInsert entityClass:[Dog class] filterPredicate:nil callback:^(NSArray<__kindof NSManagedObjectModel *> * _Nullable objects) {
        Dog *insertedDog = (Dog *)[objects firstObject];
        XCTAssertEqualObjects(insertedDog.name, @"Lucky");
        done = YES;
    }];
    
    // Insert your dog
    [self.context performBlock:^{
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Dog" inManagedObjectContext:self.context];
        Dog *dog = (Dog*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
        dog.name = @"Lucky";
        [self.context save:nil];
    }];
    
    XCTAssertTrue([self waitFor:&done timeout:2], @"Timed out waiting for response asynch method completion");
}

- (void)testHeavyInsertedDogs
{
    __block BOOL done = NO;
    
    NSPredicate *heavyDogPredicate = [NSPredicate predicateWithFormat:@"weight > 100"];
    // First setup your observer with context watcher
    [L360ContextWatcher registerObserver:self changeType:L360ContextChangeInsert entityClass:[Dog class] filterPredicate:heavyDogPredicate callback:^(NSArray<__kindof NSManagedObjectModel *> * _Nullable objects) {
        Dog *insertedDog = (Dog *)[objects firstObject];
        XCTAssertNotEqualObjects(insertedDog.name, @"Lucky");
        XCTAssertGreaterThan(insertedDog.weight.integerValue, 100);
        done = YES;
    }];
    
    // Insert your dog
    [self.context performBlock:^{
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Dog" inManagedObjectContext:self.context];
        Dog *dog = (Dog*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
        dog.name = @"Lucky";
        dog.weight = @(99);
        
        Dog *heavyDog = (Dog*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
        heavyDog.name = @"HeavyDoggie";
        heavyDog.weight = @(101);
        
        Dog *heavyDogTwo = (Dog*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
        heavyDogTwo.name = @"HeavyDoggieTwo";
        heavyDogTwo.weight = @(105);
        
        [self.context save:nil];
    }];
    
    XCTAssertTrue([self waitFor:&done timeout:2], @"Timed out waiting for response asynch method completion");
}

- (void)testUpdatedDog
{
    __block BOOL done = NO;

    // First setup your observer with context watcher
    [L360ContextWatcher registerObserver:self changeType:L360ContextChangeUpdate entityClass:[Dog class] filterPredicate:nil callback:^(NSArray<__kindof NSManagedObjectModel *> * _Nullable objects) {
        Dog *updatedDog = (Dog *)[objects firstObject];
        XCTAssertEqualObjects(updatedDog.name, @"Rufus");
        done = YES;
    }];
    
    // Insert your dog
    [self.context performBlock:^{
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Dog" inManagedObjectContext:self.context];
        Dog *dog = (Dog*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
        dog.name = @"Lucky";
        [self.context save:nil];
        
        dog.name = @"Rufus";
        [self.context save:nil];
    }];
    
    XCTAssertTrue([self waitFor:&done timeout:2], @"Timed out waiting for response asynch method completion");
}

- (void)testWillUpdateDog
{
    __block BOOL done = NO;
    
    // First setup your observer with context watcher
    [L360ContextWatcher registerObserver:self changeType:L360ContextChangeWillChange | L360ContextChangeUpdate entityClass:[Dog class] filterPredicate:nil callback:^(NSArray<__kindof NSManagedObjectModel *> * _Nullable objects) {
        Dog *preupdatedDog = (Dog *)[objects firstObject];
        XCTAssertEqualObjects(preupdatedDog.name, @"Lucky");
        done = YES;
    }];
    
    // Insert your dog
    [self.context performBlock:^{
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Dog" inManagedObjectContext:self.context];
        Dog *dog = (Dog*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
        dog.name = @"Lucky";
        [self.context save:nil];
        
        
        dog.name = @"Rufus";
        // Notifies the observers that an object will be updated
        [[L360ContextWatcher sharedInstance] contextWillUpdate:self.context withCallbackCompletion:^{
            [self.context save:nil];
        }];
        
    }];
    
    XCTAssertTrue([self waitFor:&done timeout:2], @"Timed out waiting for response asynch method completion");
}

- (void)testWillDeleteDog
{
    __block BOOL done = NO;
    
    // First setup your observer with context watcher
    [L360ContextWatcher registerObserver:self changeType:L360ContextChangeWillChange | L360ContextChangeDelete entityClass:[Dog class] filterPredicate:nil callback:^(NSArray<__kindof NSManagedObjectModel *> * _Nullable objects) {
        Dog *predeletedDog = (Dog *)[objects firstObject];
        XCTAssertEqualObjects(predeletedDog.name, @"Lucky");
        done = YES;
    }];
    
    // Insert your dog
    [self.context performBlock:^{
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Dog" inManagedObjectContext:self.context];
        Dog *dog = (Dog*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
        dog.name = @"Lucky";
        [self.context save:nil];
        
        [self.context deleteObject:dog];
        // Notifies the observers that an object will be deleted
        [[L360ContextWatcher sharedInstance] contextWillUpdate:self.context withCallbackCompletion:^{
            [self.context save:nil];
        }];
        
    }];
    
    XCTAssertTrue([self waitFor:&done timeout:2], @"Timed out waiting for response asynch method completion");
}


- (void)testObserveTwiceOnly
{
    __block BOOL done = NO;
    
    __block int observeCount = 0;
    
    [L360ContextWatcher registerObserver:self changeType:L360ContextChangeUpdate entityClass:[Dog class] filterPredicate:nil callback:^(NSArray<__kindof NSManagedObjectModel *> * _Nullable objects) {
        observeCount++;
        
        if(observeCount >= 2) {
            [L360ContextWatcher unregisterObserver:self];
            done = YES;
        }
    }];
    
    [self.context performBlock:^{
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Dog" inManagedObjectContext:self.context];
        Dog *dog = (Dog*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
        dog.name = @"Lucky";
        [self.context save:nil];
        
        dog.name = @"Rufus";
        [self.context save:nil];
        
        dog.name = @"Roofus";
        [self.context save:nil];
        
        dog.name = @"Goofus";
        [self.context save:nil];
    }];
    
    XCTAssertTrue([self waitFor:&done timeout:2], @"Timed out waiting for response asynch method completion");
}


- (void)testRemoveSpecificObserver
{
    __block BOOL done = NO;
    
    __block int observeCount = 0;

    [L360ContextWatcher registerObserver:self changeType:L360ContextChangeUpdate | L360ContextChangeInsert entityClass:[Dog class] filterPredicate:nil callback:^(NSArray<__kindof NSManagedObjectModel *> * _Nullable objects) {
        
        [L360ContextWatcher unregisterObserver:self forChangeTypes:L360ContextChangeInsert andClass:[Dog class]];
        
        observeCount++;
        if(observeCount >= 4) {
            done = YES;
        }
    }];
    
    [self.context performBlock:^{
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Dog" inManagedObjectContext:self.context];
        Dog *dog = (Dog*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
        dog.name = @"Lucky";
        [self.context save:nil];
        
        // The second dog should not trigger any update because we removed observation of insert calls after the first time
        Dog *dogTwo = (Dog*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
        dogTwo.name = @"Al";
        [self.context save:nil];
        
        dog.name = @"Rufus";
        [self.context save:nil];
        
        dog.name = @"Roofus";
        [self.context save:nil];
        
        dog.name = @"Goofus";
        [self.context save:nil];
    }];
    
    XCTAssertTrue([self waitFor:&done timeout:2], @"Timed out waiting for response asynch method completion");
}

- (void)testChangePredicate
{
    __block BOOL done = NO;
    
    __block int predicateWeight = 100;
    __block int observeCount = 0;

    NSPredicate *heavyDogPredicate = [NSPredicate predicateWithFormat:@"weight > 100"];
    // First setup your observer with context watcher
    [L360ContextWatcher registerObserver:self changeType:L360ContextChangeInsert entityClass:[Dog class] filterPredicate:heavyDogPredicate callback:^(NSArray<__kindof NSManagedObjectModel *> * _Nullable objects) {
        Dog *insertedDog = (Dog *)[objects firstObject];
        XCTAssertNotEqualObjects(insertedDog.name, @"Lucky");
        XCTAssertGreaterThan(insertedDog.weight.integerValue, predicateWeight);
        observeCount++;
        if(observeCount >= 2) {
            done = YES;
        }
    }];
    
    [self.context performBlock:^{
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Dog" inManagedObjectContext:self.context];
        Dog *dog = (Dog*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
        dog.name = @"Lucky";
        dog.weight = @(99);
        [self.context save:nil];

        Dog *heavyDog = (Dog*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
        heavyDog.name = @"HeavyDoggie";
        heavyDog.weight = @(101);
        [self.context save:nil];
        
        Dog *heavyDogTwo = (Dog*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
        heavyDogTwo.name = @"HeavyDoggieTwo";
        heavyDogTwo.weight = @(105);
        [self.context save:nil];
    }];
    
    XCTAssertTrue([self waitFor:&done timeout:2], @"Timed out waiting for response asynch method completion");
    
    NSPredicate *newHeavyDogPredicate = [NSPredicate predicateWithFormat:@"weight > 50"];
    [L360ContextWatcher changePredicate:newHeavyDogPredicate forObserver:self withChangeTypes:L360ContextChangeInsert andClass:[Dog class]];
    predicateWeight = 50;

    [self.context performBlock:^{
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Dog" inManagedObjectContext:self.context];
        Dog *newHeavyDog = (Dog*)[[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
        newHeavyDog.name = @"newHeavyDog";
        newHeavyDog.weight = @(51);
        [self.context save:nil];
    }];
    
    XCTAssertTrue([self waitFor:&done timeout:2], @"Timed out waiting for response asynch method completion");
}

@end

