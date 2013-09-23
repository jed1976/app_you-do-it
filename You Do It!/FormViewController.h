//
//  FormViewController.h
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Dropbox/Dropbox.h>
#import "Base64.h"
#import "UIImage+ProportionalFill.h"

@protocol FormViewControllerDelegate
- (void)didFinishEditingItem:(DBRecord *)record;
- (void)didCancelEditingItem:(DBRecord *)record;
@end

@interface FormViewController : UITableViewController <UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate>

@property (nonatomic) IBOutlet UISwitch *activeSwitch;
@property (nonatomic, assign) id <FormViewControllerDelegate> delegate;
@property (nonatomic) IBOutlet UITextField *detailsTextField;
@property (nonatomic) IBOutlet UITextField *nameTextField;
@property (nonatomic) IBOutlet UIButton *pickerButton;
@property (nonatomic) IBOutlet UIImageView *productImageView;
@property (nonatomic) DBRecord *record;

- (IBAction)addPhoto:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;

@end
