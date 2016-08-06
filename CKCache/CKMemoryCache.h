//
//  CKMemoryCache.h
//  CKPinCache
//
//  Created by Clark on 16/7/30.
//  Copyright © 2016年 CK. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Nullability.h"

#import "CKCacehObjectSubscripting.h"

NS_ASSUME_NONNULL_BEGIN
@class CKMemoryCache;

typedef void (^CKMemoryCacheBlock)(CKMemoryCache *cache);

typedef void (^CKMemoryCacheObjectBlock)(CKMemoryCache *cache, NSString *key, id <NSCoding> __nullable object);

//typedef void (^CKMemoryCacheFileURLBlock)(NSString *key, NSURL * __nullable fileURL);

typedef void (CKMemoryCacheContainsBlock)(BOOL containsObject);

@interface CKMemoryCache : NSObject<CKCacehObjectSubscripting>

#pragma mark - Core

/**
 *  A concurrent queue on which all callbacks are called. It is exposed here so that it can be set to target some other queue, such as a global concurrent queue with a priotity other than the default.
 */
@property (readonly) dispatch_queue_t concurrentQueue;
@property (readonly) NSInteger totalCost;
@property (assign) NSInteger consLimit;
@property (assign) NSUInteger byteLimit;
@property (assign) NSInteger ageLimit;

@property (assign) BOOL removeAllOBjectsOnMemoryWaring;
@property (assign) BOOL removeAllOBjectsOnEnteringBackground;

@property (nonatomic, assign, getter=isTTLCache) BOOL ttlCache;

#pragma mark - Event Blocks
@property (copy) CKMemoryCacheObjectBlock __nullable willAddObjectBlock;
@property (copy) CKMemoryCacheObjectBlock __nullable willRemoveObjectBlock;
@property (copy) CKMemoryCacheBlock __nullable willRemoveAllObjectsBlock;

@property (copy) CKMemoryCacheObjectBlock __nullable didAddObjectBlock;
@property (copy) CKMemoryCacheObjectBlock __nullable didRemoveObjectBlock;
@property (copy) CKMemoryCacheBlock __nullable didRemoveAllObjectsBlock;

@property (copy) CKMemoryCacheBlock __nullable didReceiveMemoryWarningBlock;
@property (copy) CKMemoryCacheBlock __nullable didEnterBackgroundBlock;

#pragma mark - Initialization

+ (instancetype)sharedCache;

#pragma mark - Asynchronous Methods
- (void)containsObjectForKey:(NSString *)key block:(CKMemoryCacheContainsBlock)block;
- (void)objectForKey:(NSString *)key block:(nullable CKMemoryCacheObjectBlock)block;
- (void)setObject:(id <NSCoding>)object forKey:(NSString *)key block:(nullable CKMemoryCacheObjectBlock)block;
- (void)setObject:(id <NSCoding>)object forKey:(NSString *)key withCost:(NSUInteger)cost block:(nullable CKMemoryCacheObjectBlock)block;
- (void)removeObjectForKey:(NSString *)key block:(nullable CKMemoryCacheObjectBlock)block;
- (void)trimToDate:(NSDate *)date block:(nullable CKMemoryCacheBlock)block;
- (void)trimToCost:(NSInteger *)cost block:(CKMemoryCacheBlock)block;
- (void)trimToCostByDate:(NSInteger *)cost block:(CKMemoryCacheBlock)block;
- (void)removeAllObects:(nullable CKMemoryCacheBlock)block;
- (void)enumerateObjectWithBlock:(CKMemoryCacheObjectBlock)block completionBlock:(nullable CKMemoryCacheBlock)completionBlock;

#pragma mark - Synchronous Methods
- (BOOL)containsObjectForKey:(NSString *)key;
- (__nullable id)objectForKey:(NSString *)key;
- (void)setObject:(id)object forKey:(NSString *)key;
- (void)setObject:(nullable id)object forKey:(NSString *)key withCost:(NSUInteger)cost;
- (void)removeObjectForKey:(nullable NSString *)key;
- (void)trimToDate:(nullable NSDate *)date;
- (void)trimToCost:(NSInteger)cost;
- (void)trimToCostByDate:(NSInteger)cost;
- (void)removeAllObects;
- (void)enumerateObjectWithBlock:(CKMemoryCacheObjectBlock)block;

@end
NS_ASSUME_NONNULL_END
