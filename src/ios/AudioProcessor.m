#import "AudioProcessor.h"
#import <Cordova/CDVAvailability.h>
#import <AudioToolbox/AudioToolbox.h>

#define kOutputBus 0
#define kInputBus 1

// our default sample rate
#define SAMPLE_RATE 44100.00

@interface AudioProcessor()
@property (nonatomic, strong) NSString* callbackId;
@property (assign) AudioBuffer audioBuffer;
@property (assign) AudioComponentInstance audioUnit;

- (void)processBuffer: (AudioBufferList*) audioBufferList;
- (BOOL)hasError:(int)statusCode file:(char*)file line:(int)line;

@end

static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
  
  // the data gets rendered here
  AudioBuffer buffer;
  
  // a variable where we check the status
  OSStatus status;
  
  /**
   This is the reference to the object who owns the callback.
   */
  AudioProcessor *audioProcessor = (__bridge AudioProcessor*) inRefCon;
  
  /**
   on this point we define the number of channels, which is mono
   for the iphone. the number of frames is usally 512 or 1024.
   */
  buffer.mDataByteSize = inNumberFrames * 2; // sample size
  buffer.mNumberChannels = 1; // one channel
  buffer.mData = malloc( inNumberFrames * 2 ); // buffer size
  
  // we put our buffer into a bufferlist array for rendering
  AudioBufferList bufferList;
  bufferList.mNumberBuffers = 1;
  bufferList.mBuffers[0] = buffer;
  
  // render input and check for error
  status = AudioUnitRender([audioProcessor audioUnit], ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList);
  [audioProcessor hasError:status file:__FILE__ line:__LINE__];
  
  [audioProcessor processBuffer:&bufferList];
  
  // clean up the buffer
  free(bufferList.mBuffers[0].mData);
  return noErr;
}


@implementation AudioProcessor

#pragma mark - Actions

-(void)start:(CDVInvokedUrlCommand*)command {
  OSStatus status = AudioOutputUnitStart(_audioUnit);
  BOOL hasError = [self hasError:status file:__FILE__ line:__LINE__];
  
  CDVPluginResult* pluginResult;
  
  if (hasError == NO) {
    _callbackId = command.callbackId;
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Has error"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }
}

-(void)stop:(CDVInvokedUrlCommand*)command {
  OSStatus status = AudioOutputUnitStop(_audioUnit);
  [self hasError:status file:__FILE__ line:__LINE__];
  _callbackId = nil;
}

#pragma mark - Processing

- (void)processBuffer: (AudioBufferList*) audioBufferList {
  
  AudioBuffer sourceBuffer = audioBufferList->mBuffers[0];
  
  // we check here if the input data byte size has changed
  if (sourceBuffer.mDataByteSize != sourceBuffer.mDataByteSize) {
    // clear old buffer
    free(sourceBuffer.mData);
    // assing new byte size and allocate them on mData
    sourceBuffer.mDataByteSize = sourceBuffer.mDataByteSize;
    sourceBuffer.mData = malloc(sourceBuffer.mDataByteSize);
  }
  int currentBuffer =0;
  int maxBuf = 800;
  
  NSMutableData *data=[[NSMutableData alloc] init];
  
  for( int y=0; y<audioBufferList->mNumberBuffers; y++ )
  {
    if (currentBuffer < maxBuf){
      AudioBuffer audioBuff = audioBufferList->mBuffers[y];
      Float32 *frame = (Float32*)audioBuff.mData;
      
      
      [data appendBytes:frame length:sourceBuffer.mDataByteSize];
      currentBuffer += audioBuff.mDataByteSize;
    }
    else{
      break;
    }
    
  }
  [self sendData:data];
}

- (void)sendData:(NSData*)data {
  CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:data];
  [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:_callbackId];
}

#pragma mark - Error Handling

- (BOOL)hasError:(int)statusCode file:(char*)file line:(int)line {
  return (statusCode);
}

#pragma mark - Init

-(void)pluginInitialize {
  [super pluginInitialize];
  OSStatus status;
  
  // We define the audio component
  AudioComponentDescription desc;
  desc.componentType = kAudioUnitType_Output; // we want to ouput
  desc.componentSubType = kAudioUnitSubType_RemoteIO; // we want in and ouput
  desc.componentFlags = 0; // must be zero
  desc.componentFlagsMask = 0; // must be zero
  desc.componentManufacturer = kAudioUnitManufacturer_Apple; // select provider
  
  // find the AU component by description
  AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
  
  // create audio unit by component
  status = AudioComponentInstanceNew(inputComponent, &_audioUnit);
  
  [self hasError:status file:__FILE__ line:__LINE__];
  
  // define that we want record io on the input bus
  UInt32 flag = 1;
  status = AudioUnitSetProperty(_audioUnit,
                                kAudioOutputUnitProperty_EnableIO, // use io
                                kAudioUnitScope_Input, // scope to input
                                kInputBus, // select input bus (1)
                                &flag, // set flag
                                sizeof(flag));
  [self hasError:status file:__FILE__ line:__LINE__];
  
  // define that we want play on io on the output bus
  status = AudioUnitSetProperty(_audioUnit,
                                kAudioOutputUnitProperty_EnableIO, // use io
                                kAudioUnitScope_Output, // scope to output
                                kOutputBus, // select output bus (0)
                                &flag, // set flag
                                sizeof(flag));
  [self hasError:status file:__FILE__ line:__LINE__];
  
  /*
   We need to specifie our format on which we want to work.
   We use Linear PCM cause its uncompressed and we work on raw data.
   for more informations check.
   
   We want 16 bits, 2 bytes per packet/frames at 44khz
   */
  AudioStreamBasicDescription audioFormat;
  audioFormat.mSampleRate			= SAMPLE_RATE;
  audioFormat.mFormatID			= kAudioFormatLinearPCM;
  audioFormat.mFormatFlags		= kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
  audioFormat.mFramesPerPacket	= 1;
  audioFormat.mChannelsPerFrame	= 1;
  audioFormat.mBitsPerChannel		= 16;
  audioFormat.mBytesPerPacket		= 2;
  audioFormat.mBytesPerFrame		= 2;
  
  // set the format on the output stream
  status = AudioUnitSetProperty(_audioUnit,
                                kAudioUnitProperty_StreamFormat,
                                kAudioUnitScope_Output,
                                kInputBus,
                                &audioFormat,
                                sizeof(audioFormat));
  
  [self hasError:status file:__FILE__ line:__LINE__];
  
  // set the format on the input stream
  status = AudioUnitSetProperty(_audioUnit,
                                kAudioUnitProperty_StreamFormat,
                                kAudioUnitScope_Input,
                                kOutputBus,
                                &audioFormat,
                                sizeof(audioFormat));
  [self hasError:status file:__FILE__ line:__LINE__];
  
  
  
  /**
   We need to define a callback structure which holds
   a pointer to the recordingCallback and a reference to
   the audio processor object
   */
  AURenderCallbackStruct callbackStruct;
  
  // set recording callback
  callbackStruct.inputProc = recordingCallback; // recordingCallback pointer
  callbackStruct.inputProcRefCon = (__bridge void * _Nullable)(self);
  
  // set input callback to recording callback on the input bus
  status = AudioUnitSetProperty(_audioUnit,
                                kAudioOutputUnitProperty_SetInputCallback,
                                kAudioUnitScope_Global,
                                kInputBus,
                                &callbackStruct,
                                sizeof(callbackStruct));
  
  [self hasError:status file:__FILE__ line:__LINE__];
  
  // reset flag to 0
  flag = 0;
  
  /*
   we need to tell the audio unit to allocate the render buffer,
   that we can directly write into it.
   */
  status = AudioUnitSetProperty(_audioUnit,
                                kAudioUnitProperty_ShouldAllocateBuffer,
                                kAudioUnitScope_Output,
                                kInputBus,
                                &flag,
                                sizeof(flag));
  
  
  /*
   we set the number of channels to mono and allocate our block size to
   1024 bytes.
   */
  _audioBuffer.mNumberChannels = 1;
  _audioBuffer.mDataByteSize = 512 * 2;
  _audioBuffer.mData = malloc( 512 * 2 );
  
  // Initialize the Audio Unit and cross fingers =)
  status = AudioUnitInitialize(_audioUnit);
  [self hasError:status file:__FILE__ line:__LINE__];
}


@end

