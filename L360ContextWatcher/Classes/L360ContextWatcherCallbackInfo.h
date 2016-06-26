//
//  L360ContextWatcherCallbackInfo.h
//  SafetyMap
//
//  Created by Yusuf Sobh on 11/5/15.
//  Copyright © 2015 Life360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "L360ContextWatcher.h"

@interface L360ContextWatcherCallbackInfo : NSObject

@property (nonatomic, strong) NSPredicate *filterPredicate;
@property (nonatomic, strong) NSPredicate *keyPathFilter; // Not yet supported
@property (nonatomic, assign) Class entityClass;
@property (nonatomic, assign) L360ContextChangeType changeTypes;
@property (nonatomic, strong) L360ContextWatcherCallback callback;
@property (nonatomic, weak) id observer;

+ (instancetype)callbackInfoWithEntityName:(Class)entityClass changeTypes:(L360ContextChangeType)changeTypes filterPredicate:(NSPredicate *)filterPredicate callback:(L360ContextWatcherCallback)callback;

@end
