//
//  AudioProcessor.h
//  MicInput
//
//  Created by Stefan Popp on 21.09.11.
//  Copyright 2011 http://http://www.stefanpopp.de/2011/capture-iphone-microphone//2011/capture-iphone-microphone/ . All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface AudioProcessor : NSObject
@property (nonatomic, copy) void (^receiveBiffer)(AudioBuffer);

- (void) doIt:(CDVInvokedUrlCommand*)command ;

-(void)start;
-(void)stop;


@end
