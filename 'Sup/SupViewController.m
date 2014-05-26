//
//  SupViewController.m
//  'Sup
//
//  Created by ahogue on 5/23/14.
//  Copyright (c) 2014 ahogue. All rights reserved.
//

#import "SupViewController.h"
#import "SupUser.h"

static NSString * const kUUID = @"63694B2B-2712-46E7-A333-E44E13B497F1";
static NSString * const kIdentifier = @"SupBeaconIdentifier";
static NSString * const kUserCellIdentifier = @"NearbyUserCell";

// NSUserDefaults keys
static NSString * const kRegisteredUsernameKey = @"user";

@interface SupViewController ()

@property (weak, nonatomic) IBOutlet UITableView *nearbyUserTable;
@property (weak, nonatomic) IBOutlet UITextField *usernameTextField;

@property (nonatomic, strong) NSArray *detectedBeacons;
@property (nonatomic, strong) CLBeaconRegion *beaconRegion;
@property (nonatomic, strong) CBPeripheralManager *peripheralManager;
@property (nonatomic, strong) CLLocationManager *locationManager;

@property (nonatomic, strong) NSArray *nearbyUsers;

@property (nonatomic, strong) NSUserDefaults *userDefaults;
@property (nonatomic, strong) SupUser *theUser;

@end

@implementation SupViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (!self.peripheralManager) {
        self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self
                                                                         queue:nil
                                                                       options:nil];
    }

    [self initDummyData];

    self.usernameTextField.delegate = self;
    self.nearbyUserTable.dataSource = self;

    self.userDefaults = [NSUserDefaults standardUserDefaults];
    NSString* username = [self.userDefaults stringForKey:kRegisteredUsernameKey];
    if (username != nil) {
        self.usernameTextField.text = username;
        [self userRegistered];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initDummyData {
#if TARGET_IPHONE_SIMULATOR
    NSMutableArray *users =
    [[NSMutableArray alloc] initWithObjects:
     [[SupUser alloc] initFromUsername:@"johng"],
     [[SupUser alloc] initFromUsername:@"jforbes"],
     nil];
    self.nearbyUsers = users;
#endif
}

- (void)userRegistered {
    // TODO: set max length on username (6 chars?)
    self.theUser = [[SupUser alloc] initFromUsername:self.usernameTextField.text];
    NSLog(@"SupUser %@,%@,%@ (reversed: %@)", self.theUser.username, self.theUser.major, self.theUser.minor,
          [self.theUser majorMinorToUsername:self.theUser.major withMinor:self.theUser.minor]);
    [self.userDefaults setObject:self.theUser.username forKey:kRegisteredUsernameKey];
    [self turnOnAdvertising];
    [self startRanging];
}

- (void)startRanging
{
    if (self.theUser == nil) {
        NSLog(@"Not turning on ranging until registered");
        return;
    }
    
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    
    self.detectedBeacons = [NSArray array];
    
    if (![CLLocationManager isRangingAvailable]) {
        NSLog(@"Couldn't turn on ranging: Ranging is not available.");
        return;
    }
    if (self.locationManager.rangedRegions.count > 0) {
        NSLog(@"Didn't turn on ranging: Ranging already on.");
        return;
    }
    
    [self createBeaconRegion];
    [self.locationManager startRangingBeaconsInRegion:self.beaconRegion];
    
    NSLog(@"startRangingBeaconsInRegion: %@.", self.beaconRegion);
}

- (void)createBeaconRegion
{
    if (self.beaconRegion)
        return;
    
    NSUUID *proximityUUID = [[NSUUID alloc] initWithUUIDString:kUUID];
    self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:proximityUUID
                                                                major:[self.theUser.major integerValue]
                                                                minor:[self.theUser.minor integerValue]
                                                           identifier:kIdentifier];
    NSLog(@"Created beacon region");
    //NSLog(@"startMonitoringForRegion %@", self.beaconRegion);
    //[self.locationManager startMonitoringForRegion:self.beaconRegion];
}

#pragma mark Beacon Broadcasting

- (void)turnOnAdvertising
{
    if (self.peripheralManager.state != CBPeripheralManagerStatePoweredOn) {
        NSLog(@"Peripheral manager is off.");
        return;
    }
    
    if (!self.theUser) {
        NSLog(@"Not turning on advertising - user is null");
        return;
    }
    
    CLBeaconRegion *region = [[CLBeaconRegion alloc] initWithProximityUUID:self.beaconRegion.proximityUUID
                                                                     major:[self.theUser.major integerValue]
                                                                     minor:[self.theUser.minor integerValue]
                                                                identifier:self.beaconRegion.identifier];
    //[self createBeaconRegion];
    region.notifyEntryStateOnDisplay = YES;
    NSDictionary *beaconPeripheralData = [region peripheralDataWithMeasuredPower:nil];
    [self.peripheralManager startAdvertising:beaconPeripheralData];
    
    NSLog(@"Turning on advertising for region: %@.", region);
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheralManager error:(NSError *)error
{
    if (error) {
        NSLog(@"Couldn't turn on advertising: %@", error);
        return;
    }
    
    if (peripheralManager.isAdvertising) {
        NSLog(@"Turned on advertising.");
    }
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheralManager
{
    if (peripheralManager.state != CBPeripheralManagerStatePoweredOn) {
        NSLog(@"Peripheral manager is off.");
        [self.peripheralManager stopAdvertising];
        return;
    }
    
    NSLog(@"Peripheral manager is on.");
    [self turnOnAdvertising];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    NSLog(@"didChangeAuthorizationStatus: %u", status);
    
    if (![CLLocationManager locationServicesEnabled]) {
        NSLog(@"Couldn't turn on ranging: Location services are not enabled.");
        return;
    }
    
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorized) {
        NSLog(@"Couldn't turn on ranging: Location services not authorised.");
        return;
    }
}

- (void)locationManager:(CLLocationManager *)manager
        didRangeBeacons:(NSArray *)beacons
               inRegion:(CLBeaconRegion *)region {
    NSLog(@"didRangeBeacons (%lu) %@", (unsigned long)[beacons count], region);
    NSMutableArray *users = [[NSMutableArray alloc] init];
    for (int ii = 0; ii < [beacons count]; ii++) {
        [users addObject:[[SupUser alloc] initFromCLBeacon:[beacons objectAtIndex:ii]]];
    }
    self.nearbyUsers = users;
}

#pragma mark Table View Management

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSLog(@"numberOfRowsInSection: %lu", (unsigned long)self.nearbyUsers.count);
    return self.nearbyUsers.count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"cellForRowAtIndexPath %@", indexPath);
    UITableViewCell *cell = nil;
    
    cell = [tableView dequeueReusableCellWithIdentifier:kUserCellIdentifier];
    
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:kUserCellIdentifier];
    
    SupUser *user = [self.nearbyUsers objectAtIndex:indexPath.row];
    cell.textLabel.text = user.username;
    cell.detailTextLabel.textColor = [UIColor grayColor];
    return cell;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self userRegistered];
    return YES;
}

@end
