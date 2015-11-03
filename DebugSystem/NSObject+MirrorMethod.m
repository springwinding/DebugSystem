//
//  NSObjec(SwizzleMethod).m
//  mybaby
//
//  Created by JiangYan on 15/10/29.
//  Copyright © 2015年 Baidu. All rights reserved.
//

#import "NSObject+MirrorMethod.h"
#import <objc/runtime.h>

@implementation NSObject (MirrorMethod)

+ (void)mirror_orginMethod:(NSString *)selector isMeta:(BOOL)meta{
    Class class = meta?self.class:self;
    NSString *templateSelecorName = [NSString stringWithFormat:@"kidmirror%@",selector];
    Method method = class_getInstanceMethod(class, NSSelectorFromString(selector));
    IMP orginIMP = method_getImplementation(method);
    const char *encoding = method_getTypeEncoding(method);
    class_addMethod(class, NSSelectorFromString(templateSelecorName), orginIMP, encoding);
    NSLog(@"%@ method is:%@", NSStringFromClass(self), selector);
}

@end
