//
//  CKDiskCache.m
//  CKPinCache
//
//  Created by Clark on 16/7/30.
//  Copyright © 2016年 CK. All rights reserved.
//

#import "CKDiskCache.h"

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_4_0
#import <UIKit/UIKit.h>
#endif

#import <pthread.h>
#define CKDiskCacheError(error) if (error) { NSLog(@"%@ (%d) ERROR: %@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [error localizedDescription]); }

static NSString * const CKDiskCachePrefix = @"com.ck.CKDiskCache";
static NSString * const CKDiskCacheSharedName = @"CKDiskCacheShared";

typedef NS_ENUM(NSInteger, CKDiskCacheCondition) {

    CKDiskCacheConditionNotReady = 0,
    CKDiskCacheConditionReady = 1,
};

@interface CKDiskCache () {

    NSConditionLock *_instanceLock;
}
@property (assign) NSUInteger byteCount;
@property (strong, nonatomic) NSURL *cacheURL;
#if OS_OBJECT_USE_OBJC
@property (strong, nonatomic) dispatch_queue_t asyncQueue;
#else
@property (assign, nonatomic) dispatch_queue_t asyncQeuue;
#endif
@property (strong, nonatomic) NSMutableDictionary *dates;
@property (strong, nonatomic) NSMutableDictionary *sizes;

@end

@implementation CKDiskCache

@synthesize willAddObjectBlock = _willAddObjectBlock;
@synthesize willRemoveObjectBlock = _willRemoveObjectBlock;
@synthesize willRemoveAllObjectsBlock = _willRemoveAllObjectsBlock;
@synthesize didAddObjectBlock = _didAddObjectBlock;
@synthesize didRemoveObjectBlock = _didRemoveObjectBlock;
@synthesize didRemoveAllObjectsBlock = _didRemoveAllObjectsBlock;
@synthesize byteLimit = _byteLimit;
@synthesize ageLimit = _ageLimit;
@synthesize ttlCache = _ttlCache;

#if TARGET_OS_IPHONE
@synthesize writingProtectionOption = _writingProtectionOption;
#endif

#pragma mark - Initialization -
- (void)dealloc {
#if !OS_OBJECT_USE_OBJC
    dispatch_release(_asyncQueue);
    _asyncQueue = nil;
#endif
}

- (instancetype)init {

    @throw [NSException exceptionWithName:@"Must initialize with a name" reason:@"CKDiskCache must be initialized with a name. Call initWithName: instead." userInfo:nil];
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
        _asyncQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@Asynchronous Queue", CKDiskCachePrefix] UTF8String], DISPATCH_QUEUE_CONCURRENT);
        _instanceLock = [[NSConditionLock alloc] initWithCondition:CKDiskCacheConditionNotReady];
        _willAddObjectBlock = nil;
        _willRemoveObjectBlock = nil;
        _willRemoveAllObjectsBlock = nil;
        _didAddObjectBlock = nil;
        _didRemoveAllObjectsBlock = nil;
        _didRemoveObjectBlock = nil;
        
        _byteCount = 0;
        _byteLimit = 0;
#if TARGET_OS_IPHONE
        _writingProtectionOption = NSDataWritingFileProtectionNone;
#endif
        _dates = [[NSMutableDictionary alloc] init];
        _sizes = [[NSMutableDictionary alloc] init];
        
        NSString *pathComponent = [[NSString alloc] initWithFormat:@"%@.%@",CKDiskCachePrefix,_name];
        _cacheURL = [NSURL fileURLWithPathComponents:@[rootPath, pathComponent]];
        dispatch_async(_asyncQueue, ^{
            [_instanceLock lockWhenCondition:CKDiskCacheConditionNotReady];
            [self _locked_createCacehDirectory];
            [self _locked_initializeDiskProperties];
            [_instanceLock unlockWithCondition:CKDiskCacheConditionReady];
            
        });
    }
    return self;
}

- (NSString *)description {

    return [[NSString alloc] initWithFormat:@"%@.%@.%p",CKDiskCachePrefix, _name, (void*)self];
}

+ (instancetype)sharedCache {

    static id cache;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        cache = [[self alloc] initWithName:CKDiskCacheSharedName];
        
    });
    return cache;
}

#pragma mark - Private Methods -

- (NSURL *)_locked_encodedFileURLForKey:(NSString *)key {

    if (![key length]) {
        return nil;
    }
    return [_cacheURL URLByAppendingPathComponent:[self encodedSring:key]];
}

- (NSString *)keyForEncodeFileURL:(NSURL *)url {

    NSString *fielName = [url lastPathComponent];
    if (!fielName) {
        return nil;
    }
    return [self decodedString:fielName];
}


- (NSString *)encodedSring:(NSString *)string {

    if (![string length]) {
        return @"";
    }
    if ([string respondsToSelector:@selector(stringByAddingPercentEncodingWithAllowedCharacters:)]) {
        return [string stringByAddingPercentEncodingWithAllowedCharacters:[[NSCharacterSet characterSetWithCharactersInString:@".:/%"] invertedSet]];
    } else {
    
        CFStringRef static const charsToEscape = CFSTR(".:%");
#pragma clang diagnostic push 
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CFStringRef escapedString = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, NULL, charsToEscape, kCFStringEncodingUTF8);
#pragma clang diagnostic pop
        return (__bridge_transfer NSString *)escapedString;
    }
}

- (NSString *)decodedString:(NSString *)string {
    if (![string length]) {
        return @"";
    }
    if ([string respondsToSelector:@selector(stringByRemovingPercentEncoding)]) {
        return [string stringByRemovingPercentEncoding];
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CFStringRef unescapedString = CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault, (__bridge CFStringRef)string, CFSTR(""), kCFStringEncodingUTF8);
#pragma clang diagnostic pop
    return (__bridge_transfer NSString *)unescapedString;
}

#pragma mark - Private trash Methods -

+ (dispatch_queue_t)sharedTrashQueue {

    static dispatch_queue_t trashQueue;
    static dispatch_once_t predicate;
    
    dispatch_once(&predicate, ^{
        NSString *queueName = [[NSString alloc] initWithFormat:@"%@.trash", CKDiskCachePrefix];
        trashQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(trashQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
        
    });
    return trashQueue;
}

+ (NSURL *)sharedTrashURL {

    static NSURL *sharedTrashURL;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        
        sharedTrashURL = [[[NSURL alloc] initFileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:CKDiskCachePrefix isDirectory:YES];
        if (![[NSFileManager defaultManager] fileExistsAtPath:[sharedTrashURL path]]) {
            NSError *error = nil;
            [[NSFileManager defaultManager] createDirectoryAtURL:sharedTrashURL withIntermediateDirectories:YES attributes:nil error:&error];
            CKDiskCacheError(error);

        }
        
    });
    return sharedTrashURL;
}

+ (BOOL)moveItemAtURLToTrash:(NSURL *)itemURL {

    if (![[NSFileManager defaultManager] fileExistsAtPath:[itemURL path]]) {
        return NO;
    }
    NSError *error = nil;
    NSString *uniqueString = [[NSProcessInfo processInfo] globallyUniqueString];
    NSURL *uniqueTrashURL = [[CKDiskCache sharedTrashURL] URLByAppendingPathComponent:uniqueString];
    BOOL moved = [[NSFileManager defaultManager] moveItemAtURL:itemURL toURL:uniqueTrashURL error:&error];
    return moved;
}
+ (void)emptyTrash {

    dispatch_async([self sharedTrashQueue], ^{
        
        NSError *searchTrashedItemError = nil;
        NSArray *trashedItems = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self sharedTrashURL] includingPropertiesForKeys:nil options:0 error:&searchTrashedItemError];
        CKDiskCacheError(searchTrashedItemError);
        for (NSURL *trashedItemURL in trashedItems) {
            NSError *removeTrashedItemError = nil;
            [[NSFileManager defaultManager] removeItemAtURL:trashedItemURL error:&removeTrashedItemError];
            CKDiskCacheError(removeTrashedItemError);
        }
        
    });
}

#pragma mark - Private Queue Methods - 
- (BOOL)_locked_createCacehDirectory {
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[_cacheURL path]]) {
        return NO;
    }
    NSError *error = nil;
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtURL:_cacheURL withIntermediateDirectories:YES attributes:nil error:&error];
    CKDiskCacheError(error);
    return success;

}

- (void)_locked_initializeDiskProperties {

    NSUInteger byteCount = 0;
    NSArray *keys = @[NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey];
    NSError *error = nil;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:_cacheURL includingPropertiesForKeys:keys options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
    CKDiskCacheError(error);
    for (NSURL *fileURL in files) {
        NSString *key = [self keyForEncodeFileURL:fileURL];
        error = nil;
        NSDictionary *dictionary = [fileURL resourceValuesForKeys:keys error:&error];
        CKDiskCacheError(error);
        NSDate *date = [dictionary objectForKey:NSURLContentModificationDateKey];
        if (date && key) {
            [_dates setObject:date forKey:key];
        }
        NSNumber *fileSize = [dictionary objectForKey:NSURLTotalFileAllocatedSizeKey];
        if (fileSize) {
            [_sizes setObject:fileSize forKey:key];
            byteCount += [fileSize unsignedIntegerValue];
        }
    }
    if (byteCount > 0) {
        self.byteCount = byteCount;
    }
}

- (BOOL)_locked_setFileModificationsDate:(NSDate *)date forURL:(NSURL *)fileURL {

    if (!date || !fileURL) {
        return NO;
    }
    NSError *error = nil;
    BOOL success = [[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate: date} ofItemAtPath:[fileURL path] error:&error];
    CKDiskCacheError(error);
    if (success) {
        NSString *key = [self keyForEncodeFileURL:fileURL];
        if (key) {
            [_dates setObject:date forKey:key];
        }
    }
    return success;
}

#pragma mark - Public Asynchronous Methods -

- (void)lockFileAccessWhileExecuteingBlock:(CKDiskCacheBlock)block {

    __weak CKDiskCache *weakSelf = self;
    dispatch_async(_asyncQueue, ^{
        CKDiskCache *strongSelf = weakSelf;
        if (block) {
            [strongSelf lock];
            block(strongSelf);
            [strongSelf unlock];
        }
        
    });
}


- (void)containsObjectForKey:(NSString *)key block:(CKDiskCacheContainsBlock)block {
    if (!key || !block) {
        return;
    }
    __weak CKDiskCache *weakSelf = self;
    dispatch_async(_asyncQueue, ^{
        CKDiskCache *strongSelf = weakSelf;
        block([strongSelf containsObjectForKey:key]);
    });
}

- (void)objectForKey:(NSString *)key block:(CKDiskCacheObjectBlock)block {
    __weak CKDiskCache *weakSelf = self;
    dispatch_async(_asyncQueue, ^{
        CKDiskCache *strongSelf = weakSelf;
        NSURL *fileURL = nil;
        id <NSCoding> object = [strongSelf objectForKey:key fileURL:&fileURL];
        if (block) {
            block(strongSelf, key, object);
        }
    });
}

- (void)fileURLForKey:(NSString *)key block:(CKDiskCacheFileURLBlock)block {

    __weak CKDiskCache *weakSelf = self;
    dispatch_async(_asyncQueue, ^{
        CKDiskCache *strongSelf = weakSelf;
        NSURL *fileURL = [strongSelf fileURLForKey:key];
        if (block) {
            [strongSelf lock];
            block(key, fileURL);
            [strongSelf unlock];
        }
    });
}
- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key block:(CKDiskCacheObjectBlock)block {

    __weak CKDiskCache *weakSelf = self;
    dispatch_async(_asyncQueue, ^{
        CKDiskCache *strongSelf = weakSelf;
        NSURL *fileURL = nil;
        [strongSelf setObject:object forKey:key fileURL:&fileURL];
        if (block) {
            block(strongSelf, key, object);
        }
    });
    
}

- (void)trimToSizeByDate:(NSInteger)trimByteCount block:(CKDiskCacheBlock)block {
    
    __weak CKDiskCache *weakSelf = self;
    dispatch_async(_asyncQueue, ^{
        CKDiskCache *strongSelf = weakSelf;
        [strongSelf trimToSizeByDate:trimByteCount];
        if (block) {
            block(strongSelf);
        }
    });
}


#pragma mark - Public synchronous Methods

- (void)synchronouslyLockFileAccessWhileExecuteingBlock:(CKDiskCacheBlock)block {
    
    if (block) {
        [self lock];
        block(self);
        [self unlock];
    }
}

- (BOOL)containsObjectForKey:(NSString *)key {

    return ([self fileURLForKey:key updateFileModificationDate:!self->_ttlCache]);
}

- (__nullable id<NSCoding>)objectForKey:(NSString *)key {

    return [self objectForKey:key fileURL:nil];
}
- (id)objectForKeyedSubscript:(NSString *)key {

    return [self objectForKey:key];
}

- (__nullable id<NSCoding>)objectForKey:(NSString *)key fileURL:(NSURL **)outFileURL {
    NSDate *now = [[NSDate alloc] init];//当前时间
    if (!key) {
        return nil;
    }
    id<NSCoding> object = nil;
    NSURL *fileURL = nil;
    [self lock];
    fileURL = [self _locked_encodedFileURLForKey:key];//根据key获取磁盘对应的缓存路径
    object = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[fileURL path]] && (!self->_ttlCache || self->_ageLimit <= 0 || fabs([[_dates objectForKey:key] timeIntervalSinceDate:now]) < self->_ageLimit)) {
        @try {
            object = [NSKeyedUnarchiver unarchiveObjectWithFile:[fileURL path]];
        } @catch (NSException *exception) {
            NSError *error = nil;
            [[NSFileManager defaultManager] removeItemAtPath:[fileURL path] error:&error];
        }
        if (!self->_ttlCache) {
            [self _locked_setFileModificationsDate:now forURL:fileURL];//修改文件的读取时间
        }
    }
    [self unlock];
    if (outFileURL) {
        *outFileURL = fileURL;
    }
    return object;

}

- (NSURL *)fileURLForKey:(NSString *)key {

    return [self fileURLForKey:key updateFileModificationDate:!self->_ttlCache];
}

- (NSURL *)fileURLForKey:(NSString *)key updateFileModificationDate:(BOOL)updateFileModificationDate {
    if (!key) {
        return nil;
    }
    NSDate *now = [[NSDate alloc] init];
    NSURL *fileURL = nil;
    [self lock];
    fileURL = [self _locked_encodedFileURLForKey:key];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[fileURL path]]) {
        if (updateFileModificationDate) {
            [self _locked_setFileModificationsDate:now forURL:fileURL];
        }
    } else {
        
        fileURL = nil;
    }
    
    [self unlock];
    return fileURL;
    
}

- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key {

    [self setObject:object forKey:key fileURL:nil];
}

- (void)setObject:(id)object forKeyedSubscript:(NSString *)key {

    [self setObject:object forKeyedSubscript:key];
}

- (void)setObject:(id)object forKey:(NSString *)key fileURL:(NSURL **)outFileURL {
    
    NSDate *now = [[NSDate alloc] init];//当前时间
    if (!key || !object) { //键值不能为空
        return;
    }
#if TARGET_OS_IPHONE
    NSDataWritingOptions writeOptions = NSDataWritingAtomic | self.writingProtectionOption;
#else
    NSDataWritingOptions witeOptions = NSDataWritingAtomic;
#endif
    NSURL *fileURL = nil;
    [self lock];
    fileURL = [self _locked_encodedFileURLForKey:key];//根据key获取磁盘路径
    CKDiskCacheObjectBlock willAddOjectBlock =  self->_willAddObjectBlock;
    if (_willAddObjectBlock) {//判断block是否为空，不为空执行block
        [self unlock];
        willAddOjectBlock(self, key, object);
        [self lock];
    }
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object];//objec 归档
    NSError *wirteError = nil;
    BOOL written = [data writeToURL:fileURL options:writeOptions error:&wirteError];// 数据写入磁盘
    CKDiskCacheError(wirteError);
    if (written) {
        [self _locked_setFileModificationsDate:now forURL:fileURL];//设置文件修改日期
        NSError *error = nil;
        NSDictionary *values = [fileURL resourceValuesForKeys:@[NSURLTotalFileAllocatedSizeKey] error:&error];
        CKDiskCacheError(error);
        NSNumber *diskFileSize = [values objectForKey:NSURLTotalFileAllocatedSizeKey];//获取文件大小
        if (diskFileSize) {
            NSNumber *prevDiskFileSize = [self->_sizes objectForKey:key];//key对应之前的文件大小
            if (prevDiskFileSize) {
                self.byteCount = self->_byteCount - [prevDiskFileSize unsignedIntegerValue];//减掉key对应之前文件大小
            }
            [self->_sizes setObject:diskFileSize forKey:key];//把key对应现在的文件大小缓存起来（保存在字典中）
            self.byteCount = self->_byteCount + [diskFileSize unsignedShortValue];//加上key对应的现在的文件大小计算总的缓存容量（磁盘）大小
        }
        if (self->_byteLimit > 0 && self->_byteCount > self->_byteLimit) {
            [self trimToSizeByDate:self->_byteLimit block:nil];
        }

    } else {
        fileURL = nil;
    }
    CKDiskCacheObjectBlock didAddOjectBlock = self->_didAddObjectBlock;
    if (didAddOjectBlock) {
        [self unlock];
        didAddOjectBlock(self, key, object);
        [self lock];
    }
    [self unlock];
    if (outFileURL) {
        *outFileURL = fileURL;
    }
}
- (void)trimToSizeByDate:(NSInteger)trimByteCount {

    if (trimByteCount) {
        [self removeAllObects];
        return;
    }
//    [self trimDiskToSizeByDate:trimByteCount];
}
#pragma Pulbic Thread Safe Accessors -

- (void)lock {
    
    [_instanceLock lockWhenCondition:CKDiskCacheConditionReady];

}
- (void)unlock {

    [_instanceLock unlockWithCondition:CKDiskCacheConditionReady];
}
@end
