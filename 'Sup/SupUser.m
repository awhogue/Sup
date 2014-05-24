//
//  SupUser.m
//  'Sup
//
//  Created by ahogue on 5/23/14.
//  Copyright (c) 2014 ahogue. All rights reserved.
//

#import "SupUser.h"

@implementation SupUser

-(SupUser*)initFromCLBeacon:(CLBeacon*)beacon {
    self.major = beacon.major;
    self.minor = beacon.minor;
    self.username = [self numberToUsername:beacon.minor];
    return self;
}

-(SupUser*)initFromUsername:(NSString*)username {
    self.major = [NSNumber numberWithUnsignedInt:12345];
    self.minor = [self usernameToNumber:username];
    self.username = username;
    return self;
}

-(NSNumber*)usernameToNumber:(NSString*)username {
    NSString* lower = [username lowercaseString];
    int codes[6] = { 0, 0, 0, 0, 0, 0 };
    for (int ii = 0; ii < [lower length] && ii < 6; ii++) {
        int asciiCode = [lower characterAtIndex:ii];
        if (asciiCode >= 97 && asciiCode <= 122) {
            codes[ii] = asciiCode - 96;  // 'a' -> 1, 'b' -> 2, etc.
        } else {
            codes[ii] = 0;
        }
    }
    int final = ((codes[0] << 25) +
                 (codes[1] << 20) +
                 (codes[2] << 15) +
                 (codes[3] << 10) +
                 (codes[4] << 5) +
                 codes[5]);
    return [NSNumber numberWithInt:final];
}

-(NSString*)numberToUsername:(NSNumber*)number {
    int mask = 31;  // 11111
    int num = [number intValue];
    int codes[6] = {
        num >> 25 & mask,
        num >> 20 & mask,
        num >> 15 & mask,
        num >> 10 & mask,
        num >> 5 & mask,
        num & mask
    };
    for (int ii = 0; ii < 6; ii++) {
        if (codes[ii] == 0) {
            codes[ii] = 32;
        } else {
            codes[ii] += 96;
        }
    }
    return [NSString stringWithFormat:@"%c%c%c%c%c%c", codes[0], codes[1], codes[2], codes[3], codes[4], codes[5]];
}

@end
