//
//  ProductImageViewController.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/17/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import "ProductImageViewController.h"

@interface ProductImageViewController ()

@end

@implementation ProductImageViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    DBError *error = nil;
    DBPath *path = [[DBPath root] childPath:self.record[@"photo"]];
    DBFile *file = [[DBFilesystem sharedFilesystem] openFile:path error:&error];

    self.navigationController.navigationBar.topItem.title = self.record[@"name"];
    
    if ( ! [self.record[@"details"] isEqualToString:@""])
        self.navigationController.navigationBar.topItem.prompt = self.record[@"details"];
    
    if ( ! [self.record[@"photo"] isEqualToString:@""])
        self.imageView.image = [[UIImage alloc] initWithData:[file readData:nil]];
}

#pragma mark - Actions

- (IBAction)done:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
