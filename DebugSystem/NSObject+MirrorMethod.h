//
//  NSObjec(SwizzleMethod).h
//  mybaby
//
//  Created by JiangYan on 15/10/29.
//  Copyright © 2015年 Baidu. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NSObject (MirrorMethod)
+ (void)mirror_orginMethod:(NSString *)selector isMeta:(BOOL)meta;
@end
