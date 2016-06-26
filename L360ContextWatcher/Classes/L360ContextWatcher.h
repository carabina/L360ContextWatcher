//
//  L360ContextWatcher.h
//  SafetyMap
//
//  Created by Yusuf Sobh on 11/5/15.
//  Copyright © 2015 Life360. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NSManagedObject;

typedef void(^L360ContextWatcherCallback)( NSArray<__kindof NSManagedObject *> * _Nullable objects);

typedef NS_OPTIONS(NSUInteger, L360ContextChangeType) {
    L360ContextChangeInsert    = (1 << 0), // 0...00001
    L360ContextChangeDelete    = (1 << 1), // 0...00010
    L360ContextChangeUpdate    = (1 << 2),
    L360ContextChangeWillChange    = (1 << 3),
    L360ContextChangeDidChange    = (1 << 4)
};
//01011 & 
typedef NS_ENUM(NSInteger, L360ContextWatcherReturnType) {
    L360ContextWatcherReturnTypeManagedObjectIDs = 0,
    L360ContextWatcherReturnTypeManagedObjects = 1
};

@interface L360ContextWatcher : NSObject

@property (nullable, nonatomic, readonly) NSOperationQueue *contextWatcherOperationQueue;

+ (nullable instancetype)sharedInstance;
/**
    Call this method to start getting context updates from the specified context and callbacks in the callbackContext
 */
+ (void)registerForContextChangeNotificationsInContext:(nullable NSManagedObjectContext *)context callbackContext:(nullable NSManagedObjectContext *)callbackContext andReturnType:(L360ContextWatcherReturnType)type;

/**
    Removes all observers
 */
+ (void)tearDown;

/*
    Register an object to receive callbacks on insert and/or update and/or delete 
    for a certain core data entity type filtered by the predicate
 */
+ (void)registerObserver:(nullable id)observer changeType:(L360ContextChangeType)changeTypes entityClass:(_Nonnull Class)entityClass filterPredicate:(nullable NSPredicate *)filterPredicate callback:(nullable L360ContextWatcherCallback)callback;

/*
    Unregister all callback methods for the specified observer
 *  ***WARNING*** DO NOT CALL THIS IN DEALLOC, observers will automatically get removed after the instance is deallocated.
 */
+ (void)unregisterObserver:(nullable id)observer;

/*
    Remove observation for a specific changeType and class
 *  ***WARNING*** DO NOT CALL THIS IN DEALLOC, observers will automatically get removed after the instance is deallocated.
*/
+ (void)unregisterObserver:(nullable id)observer forChangeTypes:(L360ContextChangeType)changeTypes andClass:(_Nonnull Class)entityClass;

/*
    Set a new predicate for the given observer
 */
+ (void)changePredicate:(nullable NSPredicate *)predicate forObserver:(nullable id)observer withChangeTypes:(L360ContextChangeType)changeTypes andClass:(_Nonnull Class)entityClass;

/*
    Notify context watcher to run all callbacks for changes found in the specified context calls completion when done running callbacks
 */
- (void)contextWillUpdate:(nullable NSManagedObjectContext *)context withCallbackCompletion:(void(^_Nullable)())completion;

@end

