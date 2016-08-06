//
//  CKMemoryCache.m
//  CKPinCache
//
//  Created by Clark on 16/7/30.
//  Copyright © 2016年 CK. All rights reserved.
//

#import "CKMemoryCache.h"

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_4_0
#import <UIKit/UIKit.h>
#endif

static NSString * const CKMemoryCachePrefix = @"com.ck.CKMemoryCache";
@interface CKMemoryCache ()
#if OS_OBJECT_USE_OBJC
@property (strong, nonatomic) dispatch_queue_t concurrentQueue;
@property (strong, nonatomic) dispatch_semaphore_t lockSemaphore;
#else
@property (strong, nonatomic) dispatch_queue_t concurrentQueue;
@property (strong, nonatomic) dispatch_semaphore_t lockSemaphore;
#endif
@property (strong, nonatomic) NSMutableDictionary *dictionary;
@property (strong, nonatomic) NSMutableDictionary *dates;
@property (strong, nonatomic) NSMutableDictionary *consts;


@end

@implementation CKMemoryCache

@synthesize willAddObjectBlock = _willAddObjectBlock;
@synthesize willRemoveObjectBlock = _willRemoveObjectBlock;
@synthesize willRemoveAllObjectsBlock = _willRemoveAllObjectsBlock;
@synthesize didAddObjectBlock = _didAddObjectBlock;
@synthesize didRemoveObjectBlock = _didRemoveObjectBlock;
@synthesize didRemoveAllObjectsBlock = _didRemoveAllObjectsBlock;
@synthesize consLimit = _consLimit;
@synthesize ageLimit = _ageLimit;
@synthesize ttlCache = _ttlCache;
@synthesize totalCost = _totalCost;
@synthesize didReceiveMemoryWarningBlock = _didReceiveMemoryWarningBlock;
@synthesize didEnterBackgroundBlock = _didEnterBackgroundBlock;

#pragma mark - Initialization -
- (void)dealloc {

    [[NSNotificationCenter defaultCenter] removeObserver:self];
#if !OS_OBJECT_USE_OBJC
    dispatch_release(_concurrentQueue);
    dispatch_release(_lockSemaphore);
    _concurrentQueue = nil;
#endif
    
}
- (instancetype)init {

    if (self = [super init]) {
        _lockSemaphore = dispatch_semaphore_create(1);
        NSString *queueName = [[NSString alloc] initWithFormat:@"%@.%p", CKMemoryCachePrefix, (void *)self ];
        _concurrentQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_CONCURRENT);
        _willAddObjectBlock = nil;
        _willRemoveObjectBlock = nil;
        _willRemoveAllObjectsBlock = nil;
        _didAddObjectBlock = nil;
        _didRemoveObjectBlock = nil;
        _didRemoveAllObjectsBlock = nil;
        
        _didEnterBackgroundBlock = nil;
        _didReceiveMemoryWarningBlock = nil;
        
        _byteLimit = 0;
        _ageLimit = 0.0;
        _totalCost = 0.0;
        
        _dictionary = [[NSMutableDictionary alloc] init];
        _dates = [[NSMutableDictionary alloc] init];
        _consts = [[NSMutableDictionary alloc] init];
        
        _removeAllOBjectsOnMemoryWaring = YES;
        _removeAllOBjectsOnEnteringBackground = YES;
        
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_4_0 && !TARGET_OS_WTCH
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveEnterBackgroundNotification:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarningNotification:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
        
    }
    return self;
}

+ (instancetype)sharedCache {

    static id cache;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        cache = [[self alloc] init];
    });
    return cache;
}

#pragma mark - Private Methods -

- (void)didReceiveEnterBackgroundNotification:(NSNotificationCenter *)notification {
    if (self.removeAllOBjectsOnEnteringBackground) {
        [self removeAllObects:nil];
    }
    __weak CKMemoryCache *weakSelf = self;
    dispatch_async(_concurrentQueue, ^{
        CKMemoryCache *strongSelf = weakSelf;
        if (!strongSelf) {
            return ;
        }
        [strongSelf lock];
        CKMemoryCacheBlock didEnterBackgroundBlock = strongSelf->_didEnterBackgroundBlock;
        [strongSelf unlock];
        if (didEnterBackgroundBlock) {
            didEnterBackgroundBlock(strongSelf);
        }
    });

    }
- (void)didReceiveMemoryWarningNotification:(NSNotificationCenter *)notification {
    if (self.removeAllOBjectsOnMemoryWaring) {
        [self removeAllObects:nil];
    }
    __weak CKMemoryCache *weakSelf = self;
    dispatch_async(_concurrentQueue, ^{
        CKMemoryCache *strongSelf = weakSelf;
        if (!strongSelf) {
            return ;
        }
        [strongSelf lock];
        CKMemoryCacheBlock didReceiveMemoryWarningBlock = strongSelf->_didReceiveMemoryWarningBlock;
        [strongSelf unlock];
        if (didReceiveMemoryWarningBlock) {
            didReceiveMemoryWarningBlock(strongSelf);
        }
    });
    
}

#pragma mark - Public Asynchronous Methods -

- (void)objectForKey:(NSString *)key block:(CKMemoryCacheObjectBlock)block {

    __weak CKMemoryCache *weakSelf = self;
    dispatch_async(_concurrentQueue, ^{
        CKMemoryCache *strongSelf = weakSelf;
        id object = [strongSelf objectForKey:key];
        if (block) {
            block(strongSelf, key, object);
        }
    });
}

- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key block:(CKMemoryCacheObjectBlock)block {

    [self setObject:object forKey:key withCost:0 block:block];
}

- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key withCost:(NSUInteger)cost block:(CKMemoryCacheObjectBlock)block {

    __weak CKMemoryCache *weakSelf = self;
    dispatch_async(_concurrentQueue, ^{
        CKMemoryCache *strongSelf = weakSelf;
        [strongSelf setObject:object forKey:key withCost:cost];
        if (block) {
            block(strongSelf, key, object);
        }
    });
}

#pragma mark - Public synchronous Methods -
- (__nullable id)objectForKey:(NSString *)key {

    if (!key) {
        return nil;
    }
    NSDate *now = [[NSDate alloc] init];
    [self lock];
    id object = nil;
    if (!self->_ttlCache || self->_ageLimit <= 0 || fabs([[_dates objectForKey:key] timeIntervalSinceDate:now]) < self->_ageLimit) {
        object = _dictionary[key];
    }
    [self unlock];
    if (object) {
        [self lock];
        _dates[key] = now;
        [self unlock];
        
    }
    return object;
}

- (id)objectForKeyedSubscript:(NSString *)key {

    return [self objectForKey:key];
}

- (void)setObject:(id)object forKey:(NSString *)key {

    [self setObject:object forKey:key withCost:0];
}

- (void)setObject:(id)object forKeyedSubscript:(NSString *)key {

    [self setObject:object forKey:key];
}

- (void)setObject:(id)object forKey:(NSString *)key withCost:(NSUInteger)cost {

    if (!key || !object) {
        return;
    }
    [self lock];
    CKMemoryCacheObjectBlock willAddOjectBlock = _willAddObjectBlock;
    CKMemoryCacheObjectBlock didAddObjectBlock = _didAddObjectBlock;
    NSUInteger constLimit = _consLimit;
    [self unlock];
    if (willAddOjectBlock) {
        willAddOjectBlock(self, key, object);
    }
    [self lock];
    NSNumber *oldCost = _consts[key];
    if (object) {
        _totalCost -= [oldCost unsignedIntegerValue];
        _dictionary[key] = object;// 将数据缓存到字典
        _dates[key] = [[NSDate alloc] init];//缓存时间
        _consts[key] = @(cost);//缓存容量；
        _totalCost += cost;
    }
    if (didAddObjectBlock) {
        didAddObjectBlock(self, key, object);
    }
    if (constLimit > 0) {
        [self trimToCostByDate:constLimit];
    }
    
}

- (void)lock {
    dispatch_semaphore_wait(_lockSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)unlock {

    dispatch_semaphore_signal(_lockSemaphore);
}
@end




