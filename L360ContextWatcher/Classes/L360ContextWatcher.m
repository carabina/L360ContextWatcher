//
//  L360ContextWatcher.m
//  SafetyMap
//
//  Created by Yusuf Sobh on 11/5/15.
//  Copyright © 2015 Life360. All rights reserved.
//

#import "L360ContextWatcher.h"
#import "L360ContextWatcherCallbackInfo.h"
#import <CoreData/CoreData.h>

@interface L360ContextWatcher ()

/*
 CallbackInfo:
 observerA: [CallbackInfoA,CallbackInfoB],
 observerB: [CallbackInfoC],
 */
@property (nonatomic, strong) NSMutableDictionary *callbackInfo;

@property (nonatomic, assign) BOOL isListeningForNotifications;

@property (nonatomic, strong) NSOperationQueue *contextWatcherOperationQueue;

@property (nonatomic, assign) L360ContextWatcherReturnType returnsObjectsOfType;

@property (nonatomic, weak) NSManagedObjectContext *callbackContext;

@end

@implementation L360ContextWatcher

static L360ContextWatcher *sharedInstance = nil;
static dispatch_once_t pred;

+ (instancetype)sharedInstance
{
    dispatch_once(&pred, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    _callbackInfo = [[NSMutableDictionary alloc] init];
    _contextWatcherOperationQueue = [[NSOperationQueue alloc] init];
    _contextWatcherOperationQueue.maxConcurrentOperationCount = 1; // Make this into a Serial Queue
}

+ (void)tearDown
{
    [[L360ContextWatcher sharedInstance].contextWatcherOperationQueue addOperationWithBlock:^{
        [L360ContextWatcher sharedInstance].contextWatcherOperationQueue = nil;
        [L360ContextWatcher sharedInstance].callbackInfo = nil;
        [L360ContextWatcher sharedInstance].callbackContext = nil;
        [L360ContextWatcher sharedInstance].isListeningForNotifications = NO;
        [[NSNotificationCenter defaultCenter] removeObserver:sharedInstance];
        
        pred = 0;
        sharedInstance = nil;
    }];
}

+ (void)registerForContextChangeNotificationsInContext:(NSManagedObjectContext *)context callbackContext:(NSManagedObjectContext *)callbackContext andReturnType:(L360ContextWatcherReturnType)type
{
    [L360ContextWatcher sharedInstance].isListeningForNotifications = YES;
    [L360ContextWatcher sharedInstance].returnsObjectsOfType = type;
    [L360ContextWatcher sharedInstance].callbackContext = callbackContext;

    [[NSNotificationCenter defaultCenter] removeObserver:[L360ContextWatcher sharedInstance]
                                                    name:NSManagedObjectContextDidSaveNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:[L360ContextWatcher sharedInstance]
                                             selector:@selector(contextUpdated:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:context];
    
}

- (void)contextWillUpdate:(NSManagedObjectContext *)context withCallbackCompletion:(void(^_Nullable)())completion
{
    __weak __typeof(self) weakSelf = self;
    [weakSelf.contextWatcherOperationQueue addOperationWithBlock:^{
        __block NSSet<__kindof NSManagedObject *> *updateObjects;
        __block NSSet<__kindof NSManagedObject *> *insertObjects;
        __block NSSet<__kindof NSManagedObject *> *deleteObjects;
        [context performBlockAndWait:^{
            updateObjects = context.updatedObjects;
            insertObjects = context.insertedObjects;
            deleteObjects = context.deletedObjects;
        }];

        [weakSelf executeCallbacksForChangeType:L360ContextChangeWillChange updateObjects:updateObjects insertObjects:insertObjects deleteObjects:deleteObjects inContext:context completion:completion];
    }];
}

- (void)contextUpdated:(NSNotification*)notification
{
    __weak __typeof(self) weakSelf = self;
    
    NSBlockOperation * contextUpdatedOperation = [NSBlockOperation blockOperationWithBlock:^{
        
        // This ensures that desired context that will be accessed in the callback will also have the latest changes.
        if(weakSelf.callbackContext) {
            [weakSelf.callbackContext performBlockAndWait:^{
                [weakSelf.callbackContext mergeChangesFromContextDidSaveNotification:notification];
            }];
        }
        
        NSDictionary *userInfo = notification.userInfo;
        NSManagedObjectContext *changedContext = [notification object];
    
        NSMutableSet * updatedObjects = [NSMutableSet set];
        NSMutableSet * insertedObjects = [NSMutableSet set];
        NSMutableSet * deletedObjects = [NSMutableSet set];
        
        [updatedObjects unionSet:userInfo[NSRefreshedObjectsKey]];
        [updatedObjects unionSet:userInfo[NSUpdatedObjectsKey]];
        [insertedObjects unionSet:userInfo[NSInsertedObjectsKey]];
        [deletedObjects unionSet:userInfo[NSDeletedObjectsKey]];
        [weakSelf executeCallbacksForChangeType:L360ContextChangeDidChange updateObjects:updatedObjects insertObjects:insertedObjects deleteObjects:deletedObjects inContext:changedContext completion:nil];
    }];
    
    // If any other operations exist we want them to run first.
    contextUpdatedOperation.queuePriority = NSOperationQueuePriorityVeryLow;
    [weakSelf.contextWatcherOperationQueue addOperation:contextUpdatedOperation];
}

- (void)executeCallbacksForChangeType:(L360ContextChangeType)changeType
                       updateObjects:(NSSet *)updatedObjects
                       insertObjects:(NSSet *)insertedObjects
                       deleteObjects:(NSSet *)deletedObjects
                           inContext:(NSManagedObjectContext *)context
                          completion:(void(^_Nullable)())completion
{
    
    if (self.callbackInfo.count == 0) {
        if(completion) {
            completion();
        }
        
        return;
    }
    
    NSMutableArray *emptyCallbackKeys = [NSMutableArray array];
    NSMutableArray *callbackInfosToExecute = [NSMutableArray array];
    // Loops through each observer with its array of callback infos
    [self.callbackInfo enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, NSMutableArray *  _Nonnull infoArray, BOOL * _Nonnull stop) {
        NSMutableArray *nilObserverInfos = [NSMutableArray array];
        // Loop through each callback for observer
        for (L360ContextWatcherCallbackInfo* info in infoArray) {
            if(info.observer == nil) {
                [nilObserverInfos addObject:info];
            } else {
                [callbackInfosToExecute addObject:info];
            }
        }
        [infoArray removeObjectsInArray:nilObserverInfos];
        if(infoArray.count == 0) {
            [emptyCallbackKeys addObject:key];
        }
    }];
    [self.callbackInfo removeObjectsForKeys:emptyCallbackKeys];
    
    // Execute callbacks after cleaning up nil observers and empty callbacks to avoid accidently mutating while iterating.
    for (L360ContextWatcherCallbackInfo* info in callbackInfosToExecute) {
        NSSet *filterResult = [self filteredForChangeType:changeType updated:updatedObjects inserted:insertedObjects deletedObjects:deletedObjects withInfo:info inContext:context];
        if([filterResult count] > 0 && info.callback) {
            [self.callbackContext performBlockAndWait:^{
                info.callback([filterResult allObjects]);
            }];
        }
    }
    
    if(completion) {
        completion();
    }
}

- (NSSet *)filteredForChangeType:(L360ContextChangeType)changeType
                         updated:(NSSet *)updatedObjects
                  inserted:(NSSet *)insertedObjects
           deletedObjects:(NSSet *)deletedObjects
                  withInfo:(L360ContextWatcherCallbackInfo *)info
                 inContext:(NSManagedObjectContext *)context
{
    NSMutableSet *objects = [NSMutableSet set];
    BOOL update = info.changeTypes & L360ContextChangeUpdate;
    BOOL insert = info.changeTypes & L360ContextChangeInsert;
    BOOL delete = info.changeTypes & L360ContextChangeDelete;
    
    // Default is to listen to did change so no need to check for it
    // Otherwise checks if the user specifies to listen to will change and update context is from will change
    BOOL observerListensToWillChange = (info.changeTypes & L360ContextChangeWillChange) > 0 ;
    BOOL observerListensToDidChange = (info.changeTypes & L360ContextChangeDidChange) > 0 ;
    BOOL observerListensToDefaultChange = !observerListensToWillChange && !observerListensToDidChange;
    BOOL observerListensToAnyChange = observerListensToWillChange && observerListensToDidChange;

    if(!observerListensToAnyChange) {
        if(observerListensToWillChange && changeType != L360ContextChangeWillChange) {
            return nil;
        } else if((observerListensToDidChange || observerListensToDefaultChange) && changeType != L360ContextChangeDidChange) {
            return nil;
        }
    }
    
    if(update) {
        [objects unionSet:updatedObjects];
    }
    
    if(insert) {
        [objects unionSet:insertedObjects];
    }
    
    if (delete) {
        [objects unionSet:deletedObjects];
    }
    
    NSMutableSet *filterIDs = [NSMutableSet set];
    
    for (NSManagedObject *object in objects) {
        __block BOOL matchesConditions = NO;
        
        [context performBlockAndWait:^{
            matchesConditions = [object isKindOfClass:info.entityClass] && (info.filterPredicate == nil || [info.filterPredicate evaluateWithObject:object]);
        }];
        
        if(matchesConditions) {
            if(self.returnsObjectsOfType == L360ContextWatcherReturnTypeManagedObjectIDs) {
                id objectID = object.objectID;
                if (objectID) {
                    [filterIDs addObject:objectID];
                }
            } else {
                __block id existingObject = nil;
                [self.callbackContext performBlockAndWait:^{
                    existingObject = [self.callbackContext existingObjectWithID:object.objectID error:nil];
                }];
                if(existingObject) {
                    [filterIDs addObject:existingObject];
                }
            }
        }
    }
    
    return filterIDs;
}

+ (void)registerObserver:(id)observer changeType:(L360ContextChangeType)changeTypes entityClass:(Class)entityClass filterPredicate:(NSPredicate *)filterPredicate callback:(L360ContextWatcherCallback)callback
{
    __weak id weakObserver = observer;
    [[L360ContextWatcher sharedInstance].contextWatcherOperationQueue addOperationWithBlock:^{
        
        NSString *key = [L360ContextWatcher keyForObserver:weakObserver];
        
        if(key == nil) {
            return;
        }
        
        L360ContextWatcherCallbackInfo *info = [L360ContextWatcherCallbackInfo callbackInfoWithEntityName:entityClass changeTypes:changeTypes filterPredicate:filterPredicate callback:callback];
        info.observer = weakObserver; // Make sure to retain the observer
        NSMutableDictionary *callbackInfo = [L360ContextWatcher sharedInstance].callbackInfo;
        NSMutableArray *infoList = [callbackInfo objectForKey:key];
        if(!infoList) {
            infoList = [[NSMutableArray alloc] init];
            [callbackInfo setObject:infoList forKey:key];
        }
        [infoList addObject:info];
    }];
}

/*
  Do not unregister observer from dealloc calls because it will try to remove an already dealloced observer causing an exception accessing the released observer
 */
+ (void)unregisterObserver:(id)observer
{
    NSString *key = [self keyForObserver:observer];

    [[L360ContextWatcher sharedInstance].contextWatcherOperationQueue addOperationWithBlock:^{
        if(observer == nil) {
            return;
        }
        
        NSMutableDictionary *callbackInfo = [L360ContextWatcher sharedInstance].callbackInfo;
        [callbackInfo removeObjectForKey:key];
    }];
}

+ (void)unregisterObserver:(id)observer forChangeTypes:(L360ContextChangeType)changeTypes andClass:(Class)entityClass
{
    __weak id weakObserver = observer;
    [[L360ContextWatcher sharedInstance].contextWatcherOperationQueue addOperationWithBlock:^{
        
        NSString *key = [self keyForObserver:weakObserver];
        
        if(key == nil) {
            return;
        }
        
        NSMutableDictionary *callbackInfo = [L360ContextWatcher sharedInstance].callbackInfo;
        NSMutableArray *infoList = [callbackInfo objectForKey:key];
        NSMutableArray *objectsToRemove = [NSMutableArray array];
        for (L360ContextWatcherCallbackInfo *info in infoList) {
            if(changeTypes == info.changeTypes && info.entityClass == entityClass) {
                [objectsToRemove addObject:info];
            }
        }
        
        [infoList removeObjectsInArray:objectsToRemove];
    }];
}

+ (void)changePredicate:(NSPredicate *)predicate forObserver:(id)observer withChangeTypes:(L360ContextChangeType)changeTypes andClass:(Class)entityClass
{
    __weak id weakObserver = observer;
    [[L360ContextWatcher sharedInstance].contextWatcherOperationQueue addOperationWithBlock:^{
        
        NSString *key = [self keyForObserver:weakObserver];

        if(key == nil) {
            return;
        }
        
        NSMutableDictionary *callbackInfo = [L360ContextWatcher sharedInstance].callbackInfo;
        NSMutableArray *infoList = [callbackInfo objectForKey:key];
        for (L360ContextWatcherCallbackInfo *info in infoList) {
            if(changeTypes == info.changeTypes && info.entityClass == entityClass) {
                info.filterPredicate = predicate;
            }
        }
    }];
}

// This is a hack that uses observer's address as the key to the dictionary
+ (NSString *)keyForObserver:(id)observer
{
    if(observer == nil) {
        return nil;
    }
    
    return [@((unsigned)observer) stringValue];
}

@end
