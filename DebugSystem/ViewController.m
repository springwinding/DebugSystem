//
//  ViewController.m
//  DebugSystem
//
//  Created by JiangYan on 15/11/3.
//  Copyright © 2015年 Mybabay. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+MirrorMethod.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface ViewController ()

@end



@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self debugClassIvas:@"_UIBackdropView"];
    [self debugClassMethod:@"_UIBackdropView"];
    UIToolbar *toolbar = [[UIToolbar alloc]init];
    [self.view addSubview:toolbar];
 }

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
   
}



static IMP aspect_getMsgForwardIMP(id self, SEL selector) {
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    // As an ugly internal runtime implementation detail in the 32bit runtime, we need to determine of the method we hook returns a struct or anything larger than id.
    // https://developer.apple.com/library/mac/documentation/DeveloperTools/Conceptual/LowLevelABI/000-Introduction/introduction.html
    // https://github.com/ReactiveCocoa/ReactiveCocoa/issues/783
    // http://infocenter.arm.com/help/topic/com.arm.doc.ihi0042e/IHI0042E_aapcs.pdf (Section 5.4)
    Method method = class_getInstanceMethod(self, selector);
    const char *encoding = method_getTypeEncoding(method);
    BOOL methodReturnsStructValue = encoding[0] == _C_STRUCT_B;
    if (methodReturnsStructValue) {
        @try {
            NSUInteger valueSize = 0;
            NSGetSizeAndAlignment(encoding, &valueSize, NULL);
            
            if (valueSize == 1 || valueSize == 2 || valueSize == 4 || valueSize == 8) {
                methodReturnsStructValue = NO;
            }
        } @catch (NSException *e) {}
    }
    if (methodReturnsStructValue) {
        msgForwardIMP = (IMP)_objc_msgForward_stret;
    }
#endif
    return msgForwardIMP;
}
//kidmirror
static void __ASPECTS_ARE_BEING_CALLED__(__unsafe_unretained NSObject *self, SEL selector, NSInvocation *invocation) {
    NSCParameterAssert(self);
    NSCParameterAssert(invocation);
    NSLog(@"------------------");
    
    NSLog(@"target is:%@ method is: %@",NSStringFromClass(self.class),NSStringFromSelector(invocation.selector));
    NSLog(@"参数为:");
    printParameters(invocation.methodSignature,invocation);
    SEL aliasSelector = aspect_aliasForSelector(invocation.selector);
    invocation.selector = aliasSelector;
    
    Class klass = object_getClass(invocation.target);
    BOOL respondsToAlias = YES;
    do {
        if ((respondsToAlias = [klass instancesRespondToSelector:aliasSelector])) {
            [invocation invoke];
            break;
        }
    }while (!respondsToAlias && (klass = class_getSuperclass(klass)));
}


static NSString *extractStructName(NSString *typeEncodeString)
{
    NSArray *array = [typeEncodeString componentsSeparatedByString:@"="];
    NSString *typeString = array[0];
    int firstValidIndex = 0;
    for (int i = 0; i< typeString.length; i++) {
        char c = [typeString characterAtIndex:i];
        if (c == '{' || c=='_') {
            firstValidIndex++;
        }else {
            break;
        }
    }
    return [typeString substringFromIndex:firstValidIndex];
}


static void printParameters(NSMethodSignature *methodSignature,NSInvocation *invocation){
    for (NSUInteger i = 2; i < methodSignature.numberOfArguments; i++) {
        const char *argumentType = [methodSignature getArgumentTypeAtIndex:i];
        switch(argumentType[0]) {
                
#define JP_FWD_ARG_CASE(_typeChar, _type) \
case _typeChar: {   \
_type arg;  \
[invocation getArgument:&arg atIndex:i];    \
NSLog(@"%@",@(arg));\
break;  \
}
                JP_FWD_ARG_CASE('c', char)
                JP_FWD_ARG_CASE('C', unsigned char)
                JP_FWD_ARG_CASE('s', short)
                JP_FWD_ARG_CASE('S', unsigned short)
                JP_FWD_ARG_CASE('i', int)
                JP_FWD_ARG_CASE('I', unsigned int)
                JP_FWD_ARG_CASE('l', long)
                JP_FWD_ARG_CASE('L', unsigned long)
                JP_FWD_ARG_CASE('q', long long)
                JP_FWD_ARG_CASE('Q', unsigned long long)
                JP_FWD_ARG_CASE('f', float)
                JP_FWD_ARG_CASE('d', double)
                JP_FWD_ARG_CASE('B', BOOL)
            case '@': {
                __unsafe_unretained id arg;
                [invocation getArgument:&arg atIndex:i];
                static const char *blockType = @encode(typeof(^{}));
                if (!strcmp(argumentType, blockType)) {
                    NSLog(@"%@",arg);
                } else {
                    NSLog(@"%@",arg);
                }
                break;
            }
            case '{': {
                NSString *typeString = extractStructName([NSString stringWithUTF8String:argumentType]);
#define JP_FWD_ARG_STRUCT(_type, _transFunc) \
if ([typeString rangeOfString:@#_type].location != NSNotFound) {    \
_type arg; \
[invocation getArgument:&arg atIndex:i];    \
NSValue *value = [NSValue _transFunc:arg];\
NSLog(@"vlaue is %@",value);\
break; \
}
                JP_FWD_ARG_STRUCT(CGRect, valueWithCGRect)
                JP_FWD_ARG_STRUCT(CGPoint, valueWithCGPoint)
                JP_FWD_ARG_STRUCT(CGSize, valueWithCGSize)
                JP_FWD_ARG_STRUCT(NSRange, valueWithRange)
                break;
            }
            case ':': {
                SEL selector;
                [invocation getArgument:&selector atIndex:i];
                NSString *selectorName = NSStringFromSelector(selector);
                NSLog(@"%@",selectorName);
                break;
            }
            case '^':
            case '*': {
                void *arg;
                [invocation getArgument:&arg atIndex:i];
                NSLog(@"%@", arg);
                break;
            }
            case '#': {
                Class arg;
                [invocation getArgument:&arg atIndex:i];
                NSLog(@"%@", NSStringFromClass(arg));
                break;
            }
            default: {
                NSLog(@"error type %s", argumentType);
                break;
            }
        }
    }
    
}
static SEL aspect_aliasForSelector(SEL selector){
    NSString *mirror = [NSString stringWithFormat:@"kidmirror%@",NSStringFromSelector(selector)];
    return NSSelectorFromString(mirror);
    
}



- (void)debugClassMethod:(NSString *)className{
    Class klass = NSClassFromString(className);
    unsigned int numMethods = 0;
    Method *method = class_copyMethodList(klass, &numMethods);
    //Method *meth = class_copyMethodList([UIView class], &numIvars);
    
    for(int i = 0; i < numMethods; i++) {
        Method thisMehod = method[i];
        SEL sel = method_getName(thisMehod);
        NSLog(@"%@", NSStringFromSelector(sel));
        [klass mirror_orginMethod:NSStringFromSelector(sel) isMeta:NO];
        const char *typeEncoding = method_getTypeEncoding(thisMehod);
        class_replaceMethod(klass, sel, aspect_getMsgForwardIMP(klass, sel), typeEncoding);
    }
    
    class_replaceMethod(klass, @selector(forwardInvocation:), (IMP)__ASPECTS_ARE_BEING_CALLED__, "v@:@");
    free(method);
}


#pragma mark print class ivars 
- (void)debugClassIvas:(NSString *)className{
    NSLog(@"---------%@IVarBegin-------------",className);
    
    Class klass = NSClassFromString(className);
    unsigned int numIvars = 0;
    
    NSString *key=nil;
    NSString *type = nil;
    
    do{
        Ivar *vars = class_copyIvarList(klass, &numIvars);
        for(int i = 0; i < numIvars; i++) {
            Ivar thisIvar = vars[i];
            key = [NSString stringWithUTF8String:ivar_getName(thisIvar)];  //获取成员变量的名字
            
            type = [NSString stringWithUTF8String:ivar_getTypeEncoding(thisIvar)]; //获取成员变量的数据类型
            NSLog(@"variable name :%@  type:%@",key, type);
        }
        free(vars);
       
    }while ((klass = class_getSuperclass(klass)));
   
    NSLog(@"---------%@IVarBegin-------------",className);
}

@end
