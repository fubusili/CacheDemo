//
//  CKCacehObjectSubscripting.h
//  CKPinCache
//
//  Created by Clark on 16/7/30.
//  Copyright © 2016年 CK. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CKCacehObjectSubscripting <NSObject>

@required
- (id)objectForKeyedSubscript:(NSString *)key;

- (void)setObject:(id)object forKeyedSubscript:(NSString *)key;

@end
