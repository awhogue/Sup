//
//  SupUser.h
//  'Sup
//
//  Created by ahogue on 5/23/14.
//  Copyright (c) 2014 ahogue. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CoreLocation;

@interface SupUser : NSObject

@property (nonatomic, strong) NSNumber* major;
@property (nonatomic, strong) NSNumber* minor;
@property (nonatomic, strong) NSNumber* accuracy;
@property (nonatomic, strong) NSString* username;

-(SupUser*)initFromCLBeacon:(CLBeacon*)beacon;
-(SupUser*)initFromUsername:(NSString*)username;
-(NSString*)numberToUsername:(NSNumber*)number;

@end
