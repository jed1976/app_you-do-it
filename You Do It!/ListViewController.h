//
//  ListViewController.h
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2014 Hand Whittled, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "FormViewController.h"

@class Dropbox;

@interface ListViewController : UIViewController <FormViewControllerDelegate, UISearchBarDelegate, UISearchDisplayDelegate, UITableViewDataSource, UITableViewDelegate>

@end
