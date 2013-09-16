//
//  FormViewController.h
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol FormViewControllerDelegate
- (void)didFinishEditingForm:(NSDictionary *)record;
- (void)didCancelAddingItem:(NSDictionary *)record;
@end

@interface FormViewController : UITableViewController <UITextFieldDelegate>

@property (nonatomic, assign) id <FormViewControllerDelegate> delegate;
@property (nonatomic, strong) IBOutlet UITextField *nameTextField;
@property (nonatomic, strong) IBOutlet UITextField *detailsTextField;
@property (nonatomic, strong) NSDictionary *record;

- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;

@end
