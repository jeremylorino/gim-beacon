/**
 * Copyright (C) 2014 Gimbal, Inc. All rights reserved.
 *
 * This software is the confidential and proprietary information of Gimbal, Inc.
 *
 * The following sample code illustrates various aspects of the Gimbal SDK.
 *
 * The sample code herein is provided for your convenience, and has not been
 * tested or designed to work on any particular system configuration. It is
 * provided AS IS and your use of this sample code, whether as provided or
 * with any modification, is at your own risk. Neither Gimbal, Inc.
 * nor any affiliate takes any liability nor responsibility with respect
 * to the sample code, and disclaims all warranties, express and
 * implied, including without limitation warranties on merchantability,
 * fitness for a specified purpose, and against infringement.
 */
#import "SightingsTableViewController.h"
#import "SightingsTableViewCell.h"
#import "Transmitter.h"

#import <FYX/FYX.h>
#import <FYX/FYXVisitManager.h>
#import <FYX/FYXSightingManager.h>
#import <FYX/FYXTransmitter.h>
#import <FYX/FYXVisit.h>

@interface SightingsTableViewController () <UITableViewDelegate, UITableViewDataSource, FYXServiceDelegate, FYXVisitDelegate>

@property NSMutableArray *transmitters;
@property FYXVisitManager *visitManager;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIView *loadingView;

@end

@implementation SightingsTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [FYX startService:self];
}

- (void)dealloc
{
    [self.visitManager stop];
}

#pragma mark - FYX Delegate methods

- (void)serviceStarted
{
    NSLog(@"#########Proximity service started!");
    
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"fyx_service_started_key"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    self.transmitters = [NSMutableArray new];
    
    [self.navigationController.navigationBar.topItem setTitleView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"nav_icon_binoculars.png"]]];
    
    self.visitManager = [[FYXVisitManager alloc] init];
    self.visitManager.delegate = self;
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    [self.visitManager startWithOptions:@{FYXVisitOptionDepartureIntervalInSecondsKey:@15,
                                          FYXSightingOptionSignalStrengthWindowKey:@(FYXSightingOptionSignalStrengthWindowNone)}];
}

- (void)startServiceFailed:(NSError *)error
{
    NSLog(@"#########Proximity service failed to start! error is: %@", error);
    
    NSString *message = @"Service failed to start, please check to make sure your Application Id and Secret are correct.";
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Proximity Service"
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

#pragma mark - FYX visit delegate

- (void)didArrive:(FYXVisit *)visit
{
    NSLog(@"############## didArrive: %@", visit);
}

- (void)didDepart:(FYXVisit *)visit
{
    NSLog(@"############## didDepart: %@", visit);
    
    Transmitter *transmitter = [[self.transmitters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", visit.transmitter.identifier]] firstObject];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[self.transmitters indexOfObject:transmitter] inSection:0];
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    if ([cell isKindOfClass:[SightingsTableViewCell class]])
    {
        [self grayOutSightingsCell:((SightingsTableViewCell*)cell)];
    }
}

- (void)receivedSighting:(FYXVisit *)visit updateTime:(NSDate *)updateTime RSSI:(NSNumber *)RSSI
{
    NSLog(@"############## receivedSighting: %@", visit);
    
    Transmitter *transmitter = [[self.transmitters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", visit.transmitter.identifier]] firstObject];
    if (transmitter == nil)
    {
        transmitter = [Transmitter new];
        transmitter.identifier = visit.transmitter.identifier;
        transmitter.name = visit.transmitter.name ? visit.transmitter.name : visit.transmitter.identifier;
        transmitter.lastSighted = [NSDate dateWithTimeIntervalSince1970:0];
        transmitter.rssi = [NSNumber numberWithInt:-100];
        transmitter.previousRSSI = transmitter.rssi;
        transmitter.batteryLevel = 0;
        transmitter.temperature = 0;
        
        [self.transmitters addObject:transmitter];
        
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:self.transmitters.count - 1 inSection:0]]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
        
        if ([self.transmitters count] == 1)
        {
            [self hideNoTransmittersView];
        }
    }
    
    transmitter.lastSighted = updateTime;
    
    if ([self shouldUpdateTransmitterCell:visit transmitter:transmitter RSSI:RSSI])
    {
        transmitter.previousRSSI = transmitter.rssi;
        transmitter.rssi = RSSI;
        transmitter.batteryLevel = visit.transmitter.battery;
        transmitter.temperature = visit.transmitter.temperature;
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[self.transmitters indexOfObject:transmitter] inSection:0];
        
        SightingsTableViewCell *cell = (SightingsTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];

        [self updateSightingsCell:cell withTransmitter:transmitter];
    }
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.transmitters count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"MyReusableCell";
    SightingsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell != nil)
    {
        Transmitter *transmitter = [self.transmitters objectAtIndex:indexPath.row];
        
        cell.transmitterNameLabel.text = transmitter.name;
        cell.transmitterIcon.image = [UIImage imageNamed:@"avatar_01"];
        
        if ([self isTransmitterAgedOut:transmitter])
        {
            [self grayOutSightingsCell:cell];
        }
        else
        {
            [self updateSightingsCell:cell withTransmitter:transmitter];
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        Transmitter *transmitter = [self.transmitters objectAtIndex:indexPath.row];
        [self.transmitters removeObject:transmitter];
        if ([self.transmitters count] == 0)
        {
            [self showNoTransmittersView];
        }
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (float)barWidthForRSSI:(NSNumber *)rssi
{
    NSInteger barMaxValue = [[NSUserDefaults standardUserDefaults] integerForKey:@"rssi_bar_max_value"];
    NSInteger barMinValue = [[NSUserDefaults standardUserDefaults] integerForKey:@"rssi_bar_min_value"];
    
    float rssiValue = [rssi floatValue];
    float barWidth;
    if (rssiValue >= barMaxValue)
    {
        barWidth = 270.0f;
    }
    else if (rssiValue <= barMinValue)
    {
        barWidth = 5.0f;
    } else
    {
        NSInteger barRange = barMaxValue - barMinValue;
        float percentage = (barMaxValue - rssiValue) / (float)barRange;
        barWidth = (1.0f - percentage) * 270.0f;
    }
    return barWidth;
}

- (void)grayOutSightingsCell:(SightingsTableViewCell *)sightingsCell
{
    if (sightingsCell)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            sightingsCell.contentView.alpha = 0.3f;
            CGRect oldFrame = sightingsCell.rssiImageView.frame;
            sightingsCell.rssiImageView.frame = CGRectMake(oldFrame.origin.x, oldFrame.origin.y, 0, oldFrame.size.height);
            sightingsCell.isGrayedOut = YES;
        });
    }
}

- (UIImage *)batteryImageForLevel:(NSNumber *)batteryLevel
{
    switch([batteryLevel integerValue])
    {
        case 0:
        case 1:
            return [UIImage imageNamed:@"battery_low.png"];
        case 2:
            return [UIImage imageNamed:@"battery_high.png"];
        case 3:
            return [UIImage imageNamed:@"battery_full.png"];
        default:
            return [UIImage imageNamed:@"battery_unknown.png"];
    }
}

- (void)updateSightingsCell:(SightingsTableViewCell *)sightingsCell withTransmitter:(Transmitter *)transmitter
{
    if (sightingsCell && transmitter)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            sightingsCell.contentView.alpha = 1.0f;
            
            float oldBarWidth = [self barWidthForRSSI:transmitter.previousRSSI];
            float newBarWidth = [self barWidthForRSSI:transmitter.rssi];
            CGRect tempFrame = sightingsCell.rssiImageView.frame;
            CGRect oldFrame = CGRectMake(tempFrame.origin.x, tempFrame.origin.y, oldBarWidth, tempFrame.size.height);
            CGRect newFrame = CGRectMake(tempFrame.origin.x, tempFrame.origin.y, newBarWidth, tempFrame.size.height);
            
            // Animate updating the RSSI indicator bar
            sightingsCell.rssiImageView.frame = oldFrame;
            [UIView animateWithDuration:1.0f animations:^{
                sightingsCell.rssiImageView.frame = newFrame;
            }];
            sightingsCell.isGrayedOut = NO;
            UIImage *batteryImage = [self batteryImageForLevel:transmitter.batteryLevel];
            [sightingsCell.batteryImageView setImage:batteryImage];
            sightingsCell.temperature.text = [NSString stringWithFormat:@"%@%@", transmitter.temperature,
                                              [NSString stringWithUTF8String:"\xC2\xB0 F" ]];
            sightingsCell.rssiLabel.text = [NSString stringWithFormat:@"%@", transmitter.rssi];
            
        });
    }
}

- (BOOL)shouldUpdateTransmitterCell:(FYXVisit *)visit transmitter:(Transmitter *)transmitter RSSI:(NSNumber *)rssi
{
    if ([transmitter.rssi isEqual:rssi] &&
        [transmitter.batteryLevel isEqualToNumber:visit.transmitter.battery] &&
        [transmitter.temperature isEqualToNumber:visit.transmitter.temperature])
    {
        return NO;
    }
    return YES;
}

- (BOOL)isTransmitterAgedOut:(Transmitter *)transmitter
{
    NSDate *now = [NSDate date];
    NSTimeInterval ageOutPeriod = [[NSUserDefaults standardUserDefaults] integerForKey:@"age_out_period"];
    
    if ([now timeIntervalSinceDate:transmitter.lastSighted] > ageOutPeriod) {
        return YES;
    }
    return NO;
}


#pragma mark - User interface manipulation

- (void)hideNoTransmittersView
{
    self.loadingView.hidden = YES;
}

- (void)showNoTransmittersView
{
    self.loadingView.hidden = NO;
}

#pragma mark - Storyboard interation

- (IBAction)refreshButtonClicked:(id)sender
{
    [self showNoTransmittersView];
    [self.transmitters removeAllObjects];
    [self.tableView reloadData];
}

@end
