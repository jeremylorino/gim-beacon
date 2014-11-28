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
#import "MainViewController.h"

#import "ContentViewController.h"

#import <ContextCore/QLContextCore.h>

#import <ContextLocation/QLContextPlaceConnector.h>
#import <ContextLocation/QLPlace.h>
#import <ContextLocation/QLPlaceEvent.h>
#import <ContextLocation/QLContentDescriptor.h>

@interface MainViewController () <QLContextPlaceConnectorDelegate, QLTimeContentDelegate>

@property (nonatomic, strong) QLContextCoreConnector *contextCoreConnector;
@property (nonatomic, strong) QLContextPlaceConnector *contextPlaceConnector;
@property (nonatomic, strong) QLContentConnector *contentConnector;

@property (weak, nonatomic) IBOutlet UIButton *getStartedButton;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation MainViewController

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.contextCoreConnector = [[QLContextCoreConnector alloc] init];
    
    self.contextPlaceConnector = [[QLContextPlaceConnector alloc] init];
    self.contextPlaceConnector.delegate = self;
    
    self.contentConnector = [[QLContentConnector alloc] init];
    self.contentConnector.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.contextCoreConnector checkStatusAndOnEnabled:^(QLContextConnectorPermissions *contextConnectorPermissions) {
        self.tableView.hidden = NO;
        self.getStartedButton.hidden = YES;
        self.navigationItem.rightBarButtonItem.enabled = YES;
    } disabled:^(NSError *error) {
        self.tableView.hidden = YES;
        self.getStartedButton.hidden = NO;
        self.navigationItem.rightBarButtonItem.enabled = NO;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"EventsKey"];
    }];
}

- (IBAction)showPermissions:(id)sender
{
    [self.contextCoreConnector showPermissionsFromViewController:self success:NULL failure:^(NSError *error) {
        NSLog(@"%@", error);
    }];
}

#pragma mark - QLContextPlaceConnectorDelegate methods

- (void)didGetPlaceEvent:(QLPlaceEvent *)placeEvent
{
    if (placeEvent.eventType == QLPlaceEventTypeAt)
    {
        [self insertEventWithTitle:[NSString stringWithFormat:@"Entered %@", placeEvent.place.name]
                              date:placeEvent.time];
    }
    else if (placeEvent.eventType == QLPlaceEventTypeLeft)
    {
        [self insertEventWithTitle:[NSString stringWithFormat:@"Exited %@", placeEvent.place.name]
                              date:placeEvent.time];
    }
}

- (void)didGetContentDescriptors:(NSArray *)contentDescriptors
{
    for (QLContentDescriptor *contentDescriptor in contentDescriptors)
    {
        [self insertEventWithTitle:contentDescriptor.title date:[NSDate date]];
        
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        localNotification.alertBody = [NSString stringWithFormat:@"%@", contentDescriptor.title];
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
    }
}

#pragma mark - QLTimeContentDelegate methods

- (void)didReceiveNotification:(QLContentNotification *)notification appState:(QLNotificationAppState)appState
{
    NSLog(@"mallmart: didReceiveNotification: %@ - %d", notification.message, appState);
    [self.contentConnector contentWithId:notification.contentId
                                 success:^(QLContent *content)
     {
         NSLog(@"requestContentForId: success: %@", content.title);
         
         ContentViewController *contentViewController = [[ContentViewController alloc] initWithNibName:nil bundle:nil];
         contentViewController.content = content;
         
         [self presentViewController:contentViewController animated:YES completion:NULL];
     }
                                 failure:^(NSError *error)
     {
         NSLog(@"requestContentForId: error: %@", error);
     }];
}

#pragma mark - Helper methods

- (NSArray *)events
{
    return [[NSUserDefaults standardUserDefaults] arrayForKey:@"EventsKey"];
}

- (void)insertEventWithTitle:(NSString *)title date:(NSDate *)date
{
    NSDictionary *event = @{@"title":title, @"date":date};
    NSMutableArray *events = [NSMutableArray arrayWithArray:[self events]];
    [events insertObject:event atIndex:0];
    
    [[NSUserDefaults standardUserDefaults] setObject:events forKey:@"EventsKey"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForItem:0 inSection:0]]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self events].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"CellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    NSDictionary *event = [self events][indexPath.row];
    cell.textLabel.text = event[@"title"];
    cell.detailTextLabel.text = [NSDateFormatter localizedStringFromDate:event[@"date"]
                                                               dateStyle:NSDateFormatterMediumStyle
                                                               timeStyle:NSDateFormatterMediumStyle];
    return cell;
}

@end
