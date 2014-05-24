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
static NSString * const kIdentifier = @"org.secondthought.SupBeaconRegion";
static NSString * const kUserCellIdentifier = @"nearbyUser";

// NSUserDefaults keys
static NSString * const kRegisteredNameKey = @"username";



@interface SupViewController ()

@property (weak, nonatomic) IBOutlet UITableView *nearbyUserTable;
@property (weak, nonatomic) IBOutlet UITextField *usernameTextField;

@property (nonatomic, strong) NSArray *detectedBeacons;
@property (nonatomic, strong) CLBeaconRegion *beaconRegion;
@property (nonatomic, strong) CBPeripheralManager *peripheralManager;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) NSNumber *beaconMajorID;
@property (nonatomic, strong) NSNumber *beaconMinorID;

@property (nonatomic, strong) NSArray *nearbyUsers;

@end

@implementation SupViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    NSString* username = [standardDefaults stringForKey:kRegisteredNameKey];
    if (username != nil) {
        self.usernameTextField.text = username;
    }
    // TODO: set max length on username (6 chars?)
    
    [self setupMajorMinorIdentifiers];
    [self startRanging];
    [self initDummyData];
    
    NSLog(@"%lu beacons", (unsigned long)[self.detectedBeacons count]);
    [self turnOnAdvertising];

    self.usernameTextField.delegate = self;
    self.nearbyUserTable.dataSource = self;
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


- (void)setupMajorMinorIdentifiers
{
    unsigned majorID = 12345;
    // TODO: encode username
    unsigned minorID = 0;
    
    self.beaconMajorID = [NSNumber numberWithUnsignedInt:majorID];
    self.beaconMinorID = [NSNumber numberWithUnsignedInt:minorID];
    NSLog(@"Got major,minor IDs: %@,%@", self.beaconMajorID, self.beaconMinorID);
}

- (void)startRanging
{
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
    
    NSLog(@"Ranging turned on for region: %@.", self.beaconRegion);
}

- (void)createBeaconRegion
{
    if (self.beaconRegion)
        return;
    
    NSUUID *proximityUUID = [[NSUUID alloc] initWithUUIDString:kUUID];
    self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:proximityUUID identifier:kIdentifier];
    [self.locationManager startMonitoringForRegion:self.beaconRegion];
}

#pragma mark Beacon Broadcasting

- (void)turnOnAdvertising
{
    if (self.peripheralManager.state != CBPeripheralManagerStatePoweredOn) {
        NSLog(@"Peripheral manager is off.");
        return;
    }
    
    time_t t;
    srand((unsigned) time(&t));
    CLBeaconRegion *region = [[CLBeaconRegion alloc] initWithProximityUUID:self.beaconRegion.proximityUUID
                                                                     major:[self.beaconMajorID integerValue]
                                                                     minor:[self.beaconMinorID integerValue]
                                                                identifier:self.beaconRegion.identifier];
    region.notifyEntryStateOnDisplay = YES;
    NSDictionary *beaconPeripheralData = [region peripheralDataWithMeasuredPower:nil];
    if (!self.peripheralManager) {
        self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self
                                                                         queue:nil
                                                                       options:nil];
    }
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
    NSMutableArray *users = [[NSMutableArray alloc] init];
    for (int ii = 0; ii < [beacons count]; ii++) {
        [users addObject:[[SupUser alloc] initFromCLBeacon:[beacons objectAtIndex:ii]]];
    }
    self.nearbyUsers = users;
}

#pragma mark Table View Management

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSLog(@"numberOfRowsInSection: %d", self.nearbyUsers.count);
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
    NSLog(@"username: %@, minor: %@, usernameFromMinor: %@", user.username, user.minor, [user numberToUsername:user.minor]);
    cell.detailTextLabel.textColor = [UIColor grayColor];
    return cell;
}

@end
