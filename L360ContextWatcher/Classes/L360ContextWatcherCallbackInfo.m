//
//  L360ContextWatcherCallbackInfo.m
//  SafetyMap
//
//  Created by Yusuf Sobh on 11/5/15.
//  Copyright © 2015 Life360. All rights reserved.
//

#import "L360ContextWatcherCallbackInfo.h"

@implementation L360ContextWatcherCallbackInfo

+ (instancetype)callbackInfoWithEntityName:(Class)entityClass changeTypes:(L360ContextChangeType)changeTypes filterPredicate:(NSPredicate *)filterPredicate callback:(L360ContextWatcherCallback)callback;
{
    L360ContextWatcherCallbackInfo *info = [[L360ContextWatcherCallbackInfo alloc] init];
    info.entityClass = entityClass;
    info.filterPredicate = filterPredicate;
    info.changeTypes = changeTypes;
    info.callback = callback;
    return info;
}

@end
