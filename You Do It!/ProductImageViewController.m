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

#pragma mark - Actions

- (IBAction)edit:(id)sender
{
    [self performSegueWithIdentifier:kSegueShowEditFormId sender:self];
}

- (void)loadRecord
{
    self.navigationItem.title = self.record[@"name"];
    
    if ( ! [self.record[@"details"] isEqualToString:@""])
        self.navigationItem.prompt = self.record[@"details"];
    
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

- (void)didFinishEditingForm:(DBRecord *)record
{
    self.record = record;
    
    [self loadRecord];
}

- (void)didCancelAddingItem:(DBRecord *)record
{
    self.record = record;
    
    [self loadRecord];    
}

@end
