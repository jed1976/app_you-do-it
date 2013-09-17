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

    self.navigationController.navigationBar.topItem.title = [self.record objectForKey:@"name"];
    
    if ( ! [[self.record objectForKey:@"details"] isKindOfClass:[NSNull class]] && ! [[self.record objectForKey:@"details"] isEqualToString:@""])
        self.navigationController.navigationBar.topItem.prompt = [self.record objectForKey:@"details"];
    
    if ( ! [[self.record objectForKey:@"photo"] isKindOfClass:[NSNull class]])
        self.imageView.image = [[UIImage alloc] initWithData:[[self.record objectForKey:@"photo"] base64DecodedData]];
}

#pragma mark - Actions

- (IBAction)done:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
