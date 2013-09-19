//
//  ProductImageViewController.h
//  You Do It!
//
//  Created by Joe Dakroub on 9/17/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Dropbox/Dropbox.h>
#import "Base64.h"
#import "FormViewController.h"

@interface ProductImageViewController : UIViewController <FormViewControllerDelegate>

@property (nonatomic, strong) DBRecord *record;
@property (nonatomic, strong) IBOutlet UIImageView *imageView;

- (IBAction)edit:(id)sender;

@end
