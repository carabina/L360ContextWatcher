# L360ContextWatcher

[![CI Status](http://img.shields.io/travis/life360/L360ContextWatcher.svg?style=flat)](https://travis-ci.org/life360/L360ContextWatcher)
[![Version](https://img.shields.io/cocoapods/v/L360ContextWatcher.svg?style=flat)](http://cocoapods.org/pods/L360ContextWatcher)
[![codecov.io](https://codecov.io/github/life360/L360ContextWatcher/coverage.svg?branch=master)](https://codecov.io/github/life360/L360ContextWatcher?branch=master)
[![Twitter](https://img.shields.io/badge/twitter-@life360-blue.svg?style=flat)](http://twitter.com/life360)
[![License](https://img.shields.io/cocoapods/l/L360ContextWatcher.svg?style=flat)](http://cocoapods.org/pods/L360ContextWatcher)
[![Platform](https://img.shields.io/cocoapods/p/L360ContextWatcher.svg?style=flat)](http://cocoapods.org/pods/L360ContextWatcher)

L360ContextWatcher provides a block based API to listen to changes in your core data model. No more NSFetchedResultsController boiler plate! You can even respond to changes before they propogate to your persistant store. It was built for the Life360 and is used on millions of devices.


## Installation

L360ContextWatcher is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "L360ContextWatcher"
```

## Usage

Example code can be found in Example/Tests/Tests.m or Example/Tests/SwiftExampleTests.swift
To run the example code, clone the repo, and run `pod install` from the Example directory first.

#### Setting up the context watcher

Objective-C
```objective-c
// Specify the context you want to listen to changes on and (optionally) a context to merge the changes onto this only needs to be done once.
[L360ContextWatcher registerForContextChangeNotificationsInContext:self.context callbackContext:self.changesContext andReturnType:L360ContextWatcherReturnTypeManagedObjects];
```

Swift
```swift
L360ContextWatcher.registerForContextChangeNotificationsInContext(self.context, callbackContext: self.changesContext, andReturnType: L360ContextWatcherReturnType.ManagedObjects)
```

#### Observing changes

Objective-C
```objective-c
// Register the type of changes you want to observe and callback block to execute
[L360ContextWatcher registerObserver:self changeType:L360ContextChangeInsert entityClass:[Dog class] filterPredicate:nil callback:^(NSArray<__kindof NSManagedObjectModel *> * _Nullable objects) {
    Dog *insertedDog = (Dog *)[objects firstObject];
    if([insertedDog.name isEqualToString:@"Lucky"]) {
        NSLog(@"Lucky was inserted!");
    }
}];

```

Swift
```swift
L360ContextWatcher.registerObserver(self, changeType: .Insert, entityClass: Dog.self, filterPredicate: nil)  { (objects:[NSManagedObject]?) in
    if let insertedDog = objects?.first as? Dog where insertedDog.name == "Lucky" {
        print("Lucky was inserted")
    }
}

```

#### Filter Predicates

Want to only listen to specific changes? Specify an NSPredicate in registerObserver just like NSFetchedResultsController.

For example:

```objective-c
NSPredicate *heavyDogPredicate = [NSPredicate predicateWithFormat:@"weight > 100"];
[L360ContextWatcher registerObserver:self changeType:L360ContextChangeInsert entityClass:[Dog class] filterPredicate:heavyDogPredicate callback:^(NSArray<__kindof NSManagedObjectModel *> * _Nullable objects) {
    // Code to run when a dog was inserted with matching predicate 
}];
```

## Todo

Finer Grained Updates - Specify key value paths to listen to updates from.

Feature requests and enhancements - Please create an issue and discuss.

## Caveats

As mentioned in the documentation, do not call unregister observer when you dealloc or deinit, otherwise it may crash. When an observer gets deallocated the context watcher will automatically remove its reference to it.

Responding to will change updates: In order to capture updates before they happen one has to call contextWillUpdate on the context that has the changes and then you can save the context and propogate the changes in the completion block. See tests for an example.

Make sure to properly choose the context which you want to listen to changes on, this is usually going to be the context that all your changes pass through before it reaches the persistant store.

## Author

Yusuf Sobh, yusuf@life360.com

## License

L360ContextWatcher is available under the MIT license. See the LICENSE file for more info.
