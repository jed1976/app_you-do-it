//
//  ProductImageViewController.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/17/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import "ProductImageViewController.h"

NSString *kSegueShowEditFormId = @"editItemSegue";

@interface ProductImageViewController()

@end

@implementation ProductImageViewController

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
    
    if ([self.record[@"details"] isEqualToString:@""])
        [self.navigationController setToolbarHidden:YES animated:YES];
    else
    {
        [self.navigationController setToolbarHidden:NO animated:YES];
        
        UILabel *detailLabel = [[UILabel alloc] initWithFrame:self.navigationController.toolbar.frame];
        [detailLabel setBackgroundColor:[UIColor clearColor]];
        [detailLabel setFont:[UIFont systemFontOfSize:15.0]];
        [detailLabel setText:self.record[@"details"]];
        [detailLabel setTextAlignment:NSTextAlignmentCenter];
        
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
            [detailLabel setTextColor:[UIColor whiteColor]];
        
        UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithCustomView:detailLabel];
        UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
        self.toolbarItems = @[spaceItem, barButton, spaceItem];
    }
    
    if ( ! [self.record[@"photo"] isEqualToString:@""])
    {
        DBError *error;
        DBPath *path = [[DBPath root] childPath:self.record[@"photo"]];
        DBFile *file = [[DBFilesystem sharedFilesystem] openFile:path error:&error];
        
        self.imageView.image = [[UIImage alloc] initWithData:[file readData:nil]];
    }
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
