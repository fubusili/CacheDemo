//
//  CKCache.h
//  CKPinCache
//
//  Created by Clark on 16/7/30.
//  Copyright © 2016年 CK. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CKDiskCache.h"
#import "CKMemoryCache.h"

NS_ASSUME_NONNULL_BEGIN
@class CKCache;
/**
 *  A callback block whic provides only the cache as an argument
 *
 *  @param cache A CKCache value
 */
typedef void (^CKCacheBlock)(CKCache *cache);

/**
 *  A callback block which provides the cache, key and object as arguments
 *
 *  @param cache  A CKCach value
 *  @param key    A specified key
 *  @param object A oject associate with specified key
 */

typedef void (^CKCacheObjectBlock)(CKCache *cache, NSString *key, id __nullable object);
/**
 *  a callback block which provides a BOOL value as argument
 *
 *  @param containsObject A BOOL value
 */
typedef void (^CKCacheObjectContainmentBlock)(BOOL containsObject);

@interface CKCache : NSObject <CKCacehObjectSubscripting>

#pragma mark - Core
/// @name Core
/**
 *  The name of this cache, used to create the <diskCache> and also appearing in stack traces
 */
@property (readonly) NSString *name;

/**
 *  A concurrent queue on which blocks passed to the asynchronous access methods are run.
 */
@property (readonly) dispatch_queue_t concurrentQueue;

/**
 *  Synchronously retrieves the total byte count of the <diskCache> on the shared disk queue.
 */
@property (readonly) NSUInteger diskByteCount;

/**
 *  The underlying disk cache, see <CKDiskCache> for additional configuration and trimming options
 */
@property (readonly) CKDiskCache *diskCache;

/**
 *  The underlying memory cache, see <CKMemoryCache> for additional configuration and trimming options
 */
@property (readonly) CKMemoryCache *memoryCache;

#pragma mark - Initialization

/**
 *  A shared cache
 *
 *  @return The shared singleton cache instance.
 */
+ (instancetype)sharedCache;

- (instancetype)init NS_UNAVAILABLE;

/**
 *  Multiple instances with the same name are allowed and can safely access
 *  the same data on disk thanks to the magic of seriality.Also used to create the <diskCache>
 *
 *  @param name The name of the cache.
 *
 *  @return A new cache with the specified name.
 */
- (instancetype)initWithName:(NSString *)name;

/**
 *  Multiple instances with the same name are allowed and can safely access 
 the same data on disk thanks to the magic of seriality.Also used to create the <diskCache>
 *
 *  @param name     The name of the cache.
 *  @param rootPath The path of the cache on disk
 *
 *  @return A new cache with the specified name.
 */
- (instancetype)initWithName:(NSString *)name rootPath:(NSString *)rootPath NS_DESIGNATED_INITIALIZER;

#pragma mark - Asynchronous Methods
/// @name Asynchronous Methods

/**
 *  This moethod determines whether an object is present for the given key in the cache. This method returns immediately and executes the passed block after the object is available, potentially in parallel with other blocks on the <concurrentQueue>
 *
 *  @param key   The key associated with the object
 *  @param block A block to be executed concurrently after the containment check happened
 */
- (void)containsObjectForKey:(NSString *)key block:(CKCacheObjectContainmentBlock)block;

/**
 *  retrieves the object for the specified key. This method returns immediately and executes the passed block after the object is available, potensially in parallel with other blcks on the <concurrentQueue>.
 *
 *  @param key   The key associated with the reqeusted object
 *  @param block A block to be executed concurrently when the object is available.
 */
- (void)objectForKey:(NSString *)key block:(CKCacheObjectBlock)block;

/**
 *  Stores an object in the cache for the specified key.This method returns immedaitely and executes the passed block after the object has been stored, potentially in parallel with other blocks on the <concurrentQueue>
 *
 *  @param object An object to store in the cache
 *  @param key    A key to associate with the object. This string will be copied
 *  @param bock   A block to be executed concurrently after the object has been stored, or nil
 */
- (void)setObject:(id <NSCoding>)object forKey:(NSString *)key block:(nullable CKCacheObjectBlock)block;

/**
 *  Removes the object for the specified key. This method returns immediately and executes the passed block after the object has been removed, potentially in parallel with other blocks on the <concurrentQueue>
 *
 *  @param key   The key associated with the object to be removed
 *  @param block A block to be executed concurrently after the object has been removed, or nil
 */
- (void)removeObjectForKey:(NSString *)key block:(nullable CKCacheObjectBlock)block;

/**
 *  Removes all objects from the cache that have not been used since the specified date. This method returns immediately and executed the passed block after after the cache has been tirimmed, potentially in parallel with other blocks ont <concurrentQueue>
 *
 *  @param date  Objects that haven't been accessed since this date are removed from the
 *  @param block A block to be executed concurrently after the cache has been trimmed, or nil.
 */
- (void)trimToDate:(NSDate *)date block:(nullable CKCacheBlock)block;

/**
 *  Removes all objects from the cache. This method returns immedaitely and executes the passed block after the cache has been cleared, potentially in parallel with other blocks on the <concurrentQueue>
 *
 *  @param block A block to be executed concurrently after the cache has been cleared, or nil.
 */
- (void)removeAllObjects:(nullable CKCacheBlock)block;

#pragma mark - Synchronous Methods

- (BOOL)containsObjectForKey:(NSString *)key;

- (__nullable id)objectForKey:(NSString *)key;

- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key;

- (void)removeObjectForKey:(NSString *)key;

- (void)trimToDate:(NSDate *)date;

- (void)removeAllObjects;

@end

NS_ASSUME_NONNULL_END
