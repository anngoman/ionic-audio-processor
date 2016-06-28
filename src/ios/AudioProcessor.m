#import "AudioProcessor.h"
#import <Cordova/CDVAvailability.h>

@implementation AudioProcessor

- (void) doIt:(CDVInvokedUrlCommand*)command {
  CDVPluginResult* pluginResult = nil;
  NSString* myarg = [command.arguments objectAtIndex:0];
  
  if (myarg != nil) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Arg was null"];
  }
  [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];


}

- (void)test {
NSLog(@"test");
}



@end

