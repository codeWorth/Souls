//
//  SocketHandler.m
//  SoulsGame
//
//  Created by Andrew Cummings on 1/12/17.
//  Copyright © 2017 Andrew Cummings. All rights reserved.
//

#import "SocketHandler.h"
#import "Game.h"

@implementation SocketHandler

static SocketHandler* instance;

+(SocketHandler*)getInstance {
    if (!instance) {
        instance = [[SocketHandler alloc] init];
    }
    return instance;
}

NSInputStream *inputStream;
NSOutputStream *outputStream;

- (void)initNetworkCommunication {
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)[Game serverIP], 80, &readStream, &writeStream);
    inputStream = (__bridge NSInputStream *)readStream;
    outputStream = (__bridge NSOutputStream *)writeStream;
    
    [inputStream setDelegate:self];
    [outputStream setDelegate:self];
    
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [inputStream open];
    [outputStream open];
}

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    
    switch (streamEvent) {
            
        case NSStreamEventOpenCompleted:
            NSLog(@"Stream opened");
            break;
            
        case NSStreamEventHasBytesAvailable:
            if (theStream == inputStream) {
                
                uint8_t buffer[1024];
                NSInteger len;
                
                while ([inputStream hasBytesAvailable]) {
                    len = [inputStream read:buffer maxLength:sizeof(buffer)];
                    if (len > 0) {
                        
                        NSString *output = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
                        
                        if (nil != output) {
                            if ([output characterAtIndex:0] == '<') {
                                [self recievedControlMessage:output];
                            } else if ([output characterAtIndex:0] == '>') {
                                [self recievedGameMessage:output];
                            }
                            NSLog(@"server said: %@", output);
                            [self sendMessage:@"<p"];
                        }
                    }
                }
            }
            break;
            
        case NSStreamEventErrorOccurred:
            NSLog(@"Can not connect to the host!");
            break;
        case NSStreamEventEndEncountered:
            break;
            
        default:
            NSLog(@"Unknown event");
    }
    
}

- (void)recievedGameMessage:(NSString*)message {
    char secondChar = [message characterAtIndex:1];
    if (secondChar == 'c') {
        NSInteger position = [[message substringWithRange:NSMakeRange(2, 1)] integerValue];
        NSInteger health = [self hexToInt:[message substringWithRange:NSMakeRange(3, 1)]];
        NSInteger shields = [self hexToInt:[message substringWithRange:NSMakeRange(4, 1)]];
        NSInteger speed = [self hexToInt:[message substringWithRange:NSMakeRange(5, 1)]];
        [self.netDelegate addCrytsalAtPosition:position withHealth:health speed:speed andShield:shields];
    } else if (secondChar == 's') {
        NSInteger position = [[message substringWithRange:NSMakeRange(2, 1)] integerValue];
        NSString* id = [message substringFromIndex:3];
        [self.netDelegate addSoulAtPosition:position withID:id];
    } else if (secondChar == 'h') {
        NSInteger sourcePos = [[message substringWithRange:NSMakeRange(2, 1)] integerValue];
        NSInteger targetPos = [[message substringWithRange:NSMakeRange(3, 1)] integerValue];
        NSString* id = [message substringFromIndex:4];
        [self.netDelegate castSpellAtHomePlayer:targetPos fromAwayPlayer:sourcePos andID:id];
    } else if (secondChar == 'a') {
        NSInteger sourcePos = [[message substringWithRange:NSMakeRange(2, 1)] integerValue];
        NSInteger targetPos = [[message substringWithRange:NSMakeRange(3, 1)] integerValue];
        NSString* id = [message substringFromIndex:4];
        [self.netDelegate castSpellAtAwayPlayer:targetPos fromAwayPlayer:sourcePos andID:id];
    }
}

- (void)recievedControlMessage:(NSString*)message {
    if ([message characterAtIndex:1] == 's') {
        [[Game instance] setShouldStart];
    } else if ([message characterAtIndex:1] == 'q') {
        [[Game instance] endGame];
    }
}

-(void)sendMessage:(NSString*)msg {
    NSData *data = [[NSData alloc] initWithData:[msg dataUsingEncoding:NSASCIIStringEncoding]];
    [outputStream write:[data bytes] maxLength:[data length]];
}

-(NSInteger)hexToInt:(NSString *)hex {
    unsigned int outVal;
    NSScanner* scanner = [NSScanner scannerWithString:hex];
    [scanner scanHexInt:&outVal];
    return outVal;
}

@end
