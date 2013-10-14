//
//  ProductImageViewController.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/17/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import "ProductImageViewController.h"

NSString *kSegueShowEditFormId = @"editItemSegue";

@implementation ProductImageViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self loadRecord];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    self.record = nil;
    self.imageView.image = nil;
}

#pragma mark - Actions

- (IBAction)edit:(id)sender
{
    [self performSegueWithIdentifier:kSegueShowEditFormId sender:self];
}

- (void)loadRecord
{
    self.navigationItem.title = self.record[@"name"];
    
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
        
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
            detailLabel.textColor = [UIColor whiteColor];
        
        UIBarButtonItem *detailBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:detailLabel];
        UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
        self.toolbarItems = @[spaceItem, detailBarButtonItem, spaceItem];
    }
    
    self.imageView.image = self.record[@"photoData"] ? [[UIImage alloc] initWithData:self.record[@"photoData"]] : nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    UINavigationController *navigationController = segue.destinationViewController;
    FormViewController *destinationController = [[navigationController childViewControllers] objectAtIndex:0];
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
