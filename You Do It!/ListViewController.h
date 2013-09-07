//
//  ListViewController.h
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <WindowsAzureMobileServices/WindowsAzureMobileServices.h>
#import "FormViewController.h"

@interface ListViewController : UITableViewController <FormViewControllerDelegate, UISearchBarDelegate, UISearchDisplayDelegate>

- (IBAction)switchToggle:(id)sender;
- (IBAction)toggleEdit:(id)sender;

@end
