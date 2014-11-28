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

#import "GMBLOptInViewController.h"

#import <ContextCore/QLContextCore.h>

@interface GMBLOptInViewController ()

@property (nonatomic) QLContextCoreConnector *contextCoreConnector;

@end

@implementation GMBLOptInViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.contextCoreConnector = [[QLContextCoreConnector alloc] init];
}

- (IBAction)didEnable
{
    [self.contextCoreConnector enableFromViewController:self.navigationController
                                                success:^{
                                                    [self dismissViewControllerAnimated:YES completion:NULL];
                                                }
                                                failure:^(NSError *error) {
                                                    NSLog(@"%@", error);
                                                }];
}

- (IBAction)didNotEnable
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)didPressShowPrivacyPolicy
{
#warning Please add link to your privacy policy if you are using this view controller
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://YOUR-PRIVACY-POLICY-URL"]];
}

- (IBAction)didPressShowTermsOfUse
{
#warning Please add link to your terms of use if you are using this view controller
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://YOUR-TERMS-OF-USE-URL"]];
}

@end
