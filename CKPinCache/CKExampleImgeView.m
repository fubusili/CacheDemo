//
//  CKExampleImgeView.m
//  CKPinCache
//
//  Created by Clark on 16/7/30.
//  Copyright © 2016年 CK. All rights reserved.
//

#import "CKExampleImgeView.h"
#import "CKCache.h"

@implementation CKExampleImgeView


- (void)setImageURL:(NSURL *)imageURL {

    _imageURL = imageURL;
    [[CKCache sharedCache] objectForKey:[imageURL absoluteString] block:^(CKCache * _Nonnull cache, NSString * _Nonnull key, id  _Nullable object) {
        if (object) {
            [self setImageOnMainThread:(UIImage *)object];
            return ;
        }
        NSLog(@"cache miss, requesting %@",imageURL);
        NSURLResponse *response = nil;
        NSURLRequest *request = [NSURLRequest requestWithURL:imageURL];
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
        UIImage *image = [[UIImage alloc] initWithData:data scale:[[UIScreen mainScreen] scale]];
        [self setImageOnMainThread:image];
        [[CKCache sharedCache] setObject:image forKey:[imageURL absoluteString]];
        
    }];
    
}

- (void)setImageOnMainThread:(UIImage *)image {

    if (!image) {
        return;
    }
    NSLog(@"setting view image %@",NSStringFromCGSize(image.size));
    dispatch_async(dispatch_get_main_queue(), ^{
        self.image = image;
    });
}

@end
