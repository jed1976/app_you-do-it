//
//  ProductImageViewController.h
//  You Do It!
//
//  Created by Joe Dakroub on 9/17/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Base64.h"

@interface ProductImageViewController : UIViewController

@property (nonatomic, strong) NSDictionary *record;
@property (nonatomic, strong) IBOutlet UIImageView *imageView;

- (IBAction)done:(id)sender;

@end
