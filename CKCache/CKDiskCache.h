//
//  CKDiskCache.h
//  CKPinCache
//
//  Created by Clark on 16/7/30.
//  Copyright © 2016年 CK. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Nullability.h"

#import "CKCacehObjectSubscripting.h"

NS_ASSUME_NONNULL_BEGIN
@class CKDiskCache;



typedef void (^CKDiskCacheBlock)(CKDiskCache *cache);

typedef void (^CKDiskCacheObjectBlock)(CKDiskCache *cache, NSString *key, id <NSCoding> __nullable object);

typedef void (^CKDiskCacheFileURLBlock)(NSString *key, NSURL * __nullable fileURL);

typedef void (CKDiskCacheContainsBlock)(BOOL containsObject);

@interface CKDiskCache : NSObject <CKCacehObjectSubscripting>

#pragma mark - Core
/**
 *  The name of this cache, used to create a directory under Librari/Caches and also appearing in stack traces
 */
@property (readonly) NSString *name;

/**
 *  The URL of the directory used by this cache, usually 'Library/Caches/com.ck.CKDiskCache.(name)'
 */
@property (readonly) NSURL *cacheURL;

@property (readonly) NSUInteger byteCount;

@property (assign) NSUInteger byteLimit;
@property (assign) NSInteger ageLimit;

#if TARGET_OS_IPHONE
@property (assign) NSDataWritingOptions writingProtectionOption;
#endif

@property (nonatomic, assign, getter=isTTLCache) BOOL ttlCache;

#pragma mark - Event Blocks
@property (copy) CKDiskCacheObjectBlock __nullable willAddObjectBlock;
@property (copy) CKDiskCacheObjectBlock __nullable willRemoveObjectBlock;
@property (copy) CKDiskCacheBlock __nullable willRemoveAllObjectsBlock;

@property (copy) CKDiskCacheObjectBlock __nullable didAddObjectBlock;
@property (copy) CKDiskCacheObjectBlock __nullable didRemoveObjectBlock;
@property (copy) CKDiskCacheBlock __nullable didRemoveAllObjectsBlock;

#pragma mark - Initialization

+ (instancetype)sharedCache;

+ (void)emptyTrash;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithName:(NSString *)name;
- (instancetype)initWithName:(NSString *)name rootPath:(NSString *)rootPath;

#pragma mark - Asynchronous Methods
- (void)lockFileAccessWhileExecuteingBlock:(nullable CKDiskCacheBlock)block;
- (void)containsObjectForKey:(NSString *)key block:(CKDiskCacheContainsBlock)block;
- (void)objectForKey:(NSString *)key block:(nullable CKDiskCacheObjectBlock)block;
/**
 *  Retrieves the fileURL for the specified key without actually reading the data from disk. This method returns immediately and executes the passed block as soon as the object is available.
 *
 *  @param key   The key associated with the requested object.
 *  @param block A block to be executed serially when the file URL is available.
 */
- (void)fileURLForKey:(NSString *)key block:(nullable CKDiskCacheFileURLBlock)block;
- (void)setObject:(id <NSCoding>)object forKey:(NSString *)key block:(nullable CKDiskCacheObjectBlock)block;
- (void)removeObjectForKey:(NSString *)key block:(nullable CKDiskCacheObjectBlock)block;
- (void)trimToDate:(NSDate *)date block:(nullable CKDiskCacheBlock)block;
- (void)trimToSize:(NSInteger)byteCount block:(nullable CKDiskCacheBlock)block;
- (void)trimToSizeByDate:(NSInteger)trimByteCount block:(nullable CKDiskCacheBlock)block;
- (void)removeAllObects:(nullable CKDiskCacheBlock)block;
- (void)enumerateObjectWithBlock:(CKDiskCacheFileURLBlock)block completionBlock:(nullable CKDiskCacheBlock)completionBlock;

#pragma mark - Synchronous Methods
- (void)synchronouslyLockFileAccessWhileExecuteingBlock:(nullable CKDiskCacheBlock)block;
- (BOOL)containsObjectForKey:(NSString *)key;
- (__nullable id <NSCoding>)objectForKey:(NSString *)key;
- (nullable NSURL *)fileURLForKey:(nullable NSString *)key;
- (void)setObject:(id <NSCoding>)object forKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;
- (void)trimToDate:(nullable NSDate *)date;
- (void)trimToSize:(NSInteger)byteCount;
- (void)trimToSizeByDate:(NSInteger)byteCount;
- (void)removeAllObects;
- (void)enumerateObjectWithBlock:(CKDiskCacheFileURLBlock)block;
@end

NS_ASSUME_NONNULL_END
