//
//  ItemViewController.h
//  You Do It!
//
//  Created by Joe Dakroub on 9/17/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Dropbox/Dropbox.h>
#import "Base64.h"
#import "FormViewController.h"

@interface ItemViewController : UIViewController <FormViewControllerDelegate>

@property (nonatomic) DBRecord *record;
@property (nonatomic) IBOutlet UIImageView *imageView;

- (IBAction)edit:(id)sender;

@end
