//
//  ListViewController.h
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Dropbox/Dropbox.h>
#import "FormViewController.h"
#import "ItemViewController.h"

@interface ListViewController : UIViewController <FormViewControllerDelegate, UISearchBarDelegate, UISearchDisplayDelegate, UITableViewDataSource, UITableViewDelegate>

- (NSInteger)activeItemCount;
- (void)setupItems;
- (void)updateBadgeCount;

@end
