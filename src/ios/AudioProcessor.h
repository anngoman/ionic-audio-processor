#import <Cordova/CDVPlugin.h>
#import <objc/runtime.h>

@interface AudioProcessor : CDVPlugin  
- (void) doIt:(CDVInvokedUrlCommand*)command;
- (void) test;

@end

