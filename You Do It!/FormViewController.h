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

- (void)didCancelEditingItem:(DBRecord *)record;
- (void)didFinishEditingItem:(DBRecord *)record;

@end

@interface FormViewController : UIViewController <UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate>

@property (nonatomic, assign) id <FormViewControllerDelegate> delegate;
@property DBRecord *record;

@end
