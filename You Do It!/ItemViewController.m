//
//  ItemViewController.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/17/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import "ItemViewController.h"

static NSString *kSegueShowEditFormId = @"editItemSegue";

@interface ItemViewController()

@property IBOutlet UIImageView *imageView;

- (IBAction)edit:(id)sender;

@end


@implementation ItemViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self loadRecord];
}

#pragma mark - Actions

- (IBAction)edit:(id)sender
{
    [self performSegueWithIdentifier:kSegueShowEditFormId sender:self];
}

- (void)loadRecord
{
    self.navigationItem.title = self.record[@"name"];
    self.imageView.image = [[UIImage alloc] initWithData:self.record[@"photoData"]];
    
    if ([self.record[@"details"] isEqualToString:@""])
        [self.navigationController setToolbarHidden:YES animated:YES];
    else
    {
        [self.navigationController setToolbarHidden:NO animated:YES];
        
        UILabel *detailLabel = [[UILabel alloc] initWithFrame:self.navigationController.toolbar.frame];
        detailLabel.alpha = 0.0;
        detailLabel.backgroundColor = [UIColor clearColor];
        detailLabel.font = [UIFont systemFontOfSize:15.0];
        detailLabel.text = self.record[@"details"];
        detailLabel.textAlignment = NSTextAlignmentCenter;
        detailLabel.textColor = floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1 ? [UIColor whiteColor] : [UIColor blackColor];
        
        UIBarButtonItem *detailBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:detailLabel];
        UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
        self.toolbarItems = @[spaceItem, detailBarButtonItem, spaceItem];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    UINavigationController *navigationController = segue.destinationViewController;
    FormViewController *destinationController = [[navigationController childViewControllers] firstObject];
    destinationController.delegate = self;
    [destinationController setRecord:self.record];
}

#pragma mark - FormViewControllerDelegate

- (void)didFinishEditingItem:(DBRecord *)record
{
    self.record = record;
    
    [self loadRecord];
}

- (void)didCancelEditingItem:(DBRecord *)record
{
    self.record = record;
    
    [self loadRecord];    
}

@end
