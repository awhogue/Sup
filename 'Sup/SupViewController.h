//
//  SupViewController.h
//  'Sup
//
//  Created by ahogue on 5/23/14.
//  Copyright (c) 2014 ahogue. All rights reserved.
//

#import <UIKit/UIKit.h>
@import CoreLocation;
@import CoreBluetooth;

@interface SupViewController : UIViewController <CLLocationManagerDelegate, CBPeripheralManagerDelegate, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@end
