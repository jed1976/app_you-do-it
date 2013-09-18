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
- (void)didFinishEditingForm:(DBRecord *)record;
- (void)didCancelAddingItem:(DBRecord *)record;
@end

@interface FormViewController : UITableViewController <UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate>

@property (nonatomic, assign) id <FormViewControllerDelegate> delegate;
@property (nonatomic, strong) IBOutlet UITextField *detailsTextField;
@property (nonatomic, strong) IBOutlet UITextField *nameTextField;
@property (nonatomic, strong) IBOutlet UIButton *pickerButton;
@property (nonatomic, strong) IBOutlet UIImageView *productImageView;
@property (nonatomic, strong) DBRecord *record;

- (IBAction)addPhoto:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;

@end
