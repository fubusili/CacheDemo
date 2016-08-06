//
//  CKCache.m
//  CKPinCache
//
//  Created by Clark on 16/7/30.
//  Copyright © 2016年 CK. All rights reserved.
//

#import "CKCache.h"

static NSString *const CKCachePrefix = @"com.ck.CKCache";
static NSString *const CKCacheSharedName = @"CKCacheShared";

@interface CKCache ()
#if OS_OBJECT_USE_OBJC // iOS 6.0以后才有ARC(自动引用计数)
@property (strong, nonatomic) dispatch_queue_t concurrentQueue;
#else
@property (assign, nonatomic) dispatch_queue_t concurrentQueue;
#endif
@end

@implementation CKCache

#pragma mark - Initialization 

#if !OS_OBJECT_USE_OBJC
- (void)dealloc {

    dispatch_release(_concurrentQueue);
    _concurrentQueue = nil;
}
#endif

- (instancetype)init {

    @throw [NSException exceptionWithName:@"must initialize with a name" reason:@"CKCache must be initialized with a name. Call initwithName: instead." userInfo:nil];
    return [self initWithName:@""];
}

- (instancetype)initWithName:(NSString *)name {

    return [self initWithName:name rootPath:[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject]];
}

- (instancetype)initWithName:(NSString *)name rootPath:(NSString *)rootPath {

    if (!name) {
        return nil;
    }
    if (self = [super init]) {
        _name = [name copy];
        NSString *queueName = [[NSString alloc] initWithFormat:@"%@.%p",CKCachePrefix,(void *)self];
        _concurrentQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@Asynchronous Queue",queueName] UTF8String], DISPATCH_QUEUE_CONCURRENT);
        _diskCache = [[CKDiskCache alloc] initWithName:_name rootPath:rootPath];
        _memoryCache = [[CKMemoryCache alloc] init];
    }
    return self;
}

- (NSString *)description {

    return [[NSString alloc] initWithFormat:@"%@.%@.%p",CKCachePrefix, _name, (void *)self];
}

+ (instancetype)sharedCache {

    static id cache;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        cache = [[self alloc] initWithName:CKCacheSharedName];
    });
    return cache;
}

#pragma mark - Public Asynchronous Methods -
- (void)containsObjectForKey:(NSString *)key block:(CKCacheObjectContainmentBlock)block {

    if (!key || !block) {
        return;
    }
    __weak CKCache *weakSelf = self;
    dispatch_async(_concurrentQueue, ^{
        CKCache *strongSelf = weakSelf;
        
        BOOL containsObject = [strongSelf containsObjectForKey:key];
        block(containsObject);
        
    });
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
- (void)objectForKey:(NSString *)key block:(CKCacheObjectBlock)block {

    if (!key || !block) {
        return;
    }
    __weak CKCache *weakSelf = self;
    
    dispatch_async(_concurrentQueue, ^{
        CKCache *strongSelf = weakSelf;
        if (!strongSelf)
            return;
        [strongSelf -> _memoryCache objectForKey:key block:^(CKMemoryCache * cache, NSString * memoryCacheKey, id memoryCacheObject) {
            CKCache *strongSelf = weakSelf;
            if (!strongSelf) {
                return ;
            }
            if (memoryCacheObject) {
                [strongSelf -> _diskCache fileURLForKey:memoryCacheKey block:NULL];
                dispatch_async(strongSelf -> _concurrentQueue, ^{
                    CKCache *strongSelf = weakSelf;
                    if (strongSelf) {
                        block(strongSelf, memoryCacheKey, memoryCacheObject);
                    }
                });
            } else {
            
                [strongSelf -> _diskCache objectForKey:memoryCacheKey block:^(CKDiskCache * _Nonnull cache, NSString * _Nonnull diskCacheKey, id<NSCoding>  _Nullable diskCacheObject) {
                    CKCache *strongSelf = weakSelf;
                    if (!strongSelf) {
                        return ;
                    }
                    [strongSelf -> _memoryCache setObject:diskCacheObject forKey:diskCacheKey block:nil];
                    dispatch_async(strongSelf -> _concurrentQueue, ^{
                        CKCache *strongSelf = weakSelf;
                        if (strongSelf) {
                            block(strongSelf, diskCacheKey, diskCacheObject);
                        }
                    });
                }];
            }
        }];
    });
}
#pragma clang diagnostic pop
- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key block:(CKCacheObjectBlock)block {
    if (!key || !object) {
        return;
    }
    dispatch_group_t group = nil;
    CKMemoryCacheObjectBlock memBlock = nil;
    CKDiskCacheObjectBlock diskBlock = nil;
    if (block) {
        group = dispatch_group_create();
        dispatch_group_enter(group);
        dispatch_group_enter(group);
        memBlock = ^(CKMemoryCache *memoryCache, NSString *memoryCacheKey, id memoryCacheObject){
            dispatch_group_leave(group);
        };
        diskBlock = ^(CKDiskCache *diskCache, NSString *diskCacheKey, id <NSCoding> memoryCacheObject) {
            dispatch_group_leave(group);
        };
    }
    [_memoryCache setObject:object forKey:key block:memBlock];
    [_diskCache setObject:object forKey:key block:diskBlock];
    if (group) {
        __weak CKCache *weakSelf = self;
        dispatch_group_notify(group, _concurrentQueue, ^{
            CKCache *strongSelf = weakSelf;
            if (strongSelf) {
                block(strongSelf, key, object);
            }
            
        });
#if !OS_OBJECT_USE_OBJC
        dispatch_release(group);
#endif
    }
}

#pragma mack - Public Synchronous Accessors -
- (BOOL)containsObjectForKey:(NSString *)key {

    if (!key) {
        return NO;
    }
    return [_memoryCache containsObjectForKey:key] || [_diskCache containsObjectForKey:key];
}
- (__nullable id)objectForKey:(NSString *)key {

    if (!key) {
        return nil;
    }
    __block id object = nil;
    object = [_memoryCache objectForKey:key];
    if (object) {
        [_diskCache fileURLForKey:key block:NULL];
    } else {
    
        object = [_diskCache objectForKey:key];
        [_memoryCache setObject:object forKey:key];
    }
    return object;
}
- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key {

    if (!key || !object) {
        return;
    }
    [_memoryCache setObject:object forKey:key];
    [_diskCache setObject:object forKey:key];
}

- (id)objectForKeyedSubscript:(NSString *)key {

    return [self objectForKey:key];
}
- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key {

    [self setObject:obj forKey:key];
}
@end
