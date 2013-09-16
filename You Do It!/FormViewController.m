//
//  FormViewController.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import "FormViewController.h"

NSInteger kAddPhotoAlertSheetTag = 1000;
NSInteger kDeletePhotoAlertSheetTag = 2000;

@implementation FormViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[[[[self navigationController] navigationBar] topItem] rightBarButtonItem] setEnabled:[[self.nameTextField text] isEqualToString:@""]];
    
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
        [self.navigationController.navigationBar setTintColor:[UIColor orangeColor]];
    
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];

    [self loadRecord];
    
    [self.nameTextField addTarget:self action:@selector(nameTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self.nameTextField becomeFirstResponder];
    
    [self togglePickerButtonText];
}

#pragma mark - Actions

- (IBAction)addPhoto:(id)sender
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
    [actionSheet setDelegate:self];
    [actionSheet setTag:kAddPhotoAlertSheetTag];
    
    BOOL supportsCamera = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    
    if (supportsCamera)
        [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertTakePhoto", nil)];
    
    [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertChoosePhoto", nil)];

    if (self.productImageView.image != nil)
        [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertDeletePhoto", nil)];
    
    [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertCancelButton", nil)];
//    [actionSheet setCancelButtonIndex:supportsCamera ? 2 : 1];
    
    [actionSheet showInView:self.navigationController.view];
}

- (IBAction)cancel:(id)sender
{
    if ([[self.nameTextField text] isEqualToString:@""])
        [_delegate didCancelAddingItem:self.record];
    
    [self.nameTextField resignFirstResponder];
    [self.detailsTextField resignFirstResponder];
    
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)deletePhoto
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"UIAlertCancelButton", nil)
                                               destructiveButtonTitle:NSLocalizedString(@"UIAlertDeletePhoto", nil)
                                                    otherButtonTitles:nil, nil];
    [actionSheet setTag:kDeletePhotoAlertSheetTag];
    [actionSheet showInView:self.navigationController.view];
    
}

- (void)dismissPicker:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:^(void) {
        [self.nameTextField becomeFirstResponder];
    }];
}

- (IBAction)done:(id)sender
{
    [self updateRecord];
    
    [_delegate didFinishEditingForm:self.record];

    [self cancel:self];
}

- (void)loadRecord
{
    [self.nameTextField setText:[self.record valueForKey:@"name"]];
    
    // Temporarily check for NSNull as the previous version of the app did not contain
    // a "details" column and the Azure API return NSNull in such cases.
    [self.detailsTextField setText:[[self.record valueForKey:@"details"] isKindOfClass:[NSNull class]] ? @"" : [self.record valueForKey:@"details"]];
    
    if ( ! [[self.record objectForKey:@"photo"] isKindOfClass:[NSNull class]])
        [self.productImageView setImage:[[UIImage alloc] initWithData:[[self.record objectForKey:@"photo"] base64DecodedData]]];
}

- (void)togglePickerButtonText
{
    [self.pickerButton setTitle:NSLocalizedString(self.productImageView.image == nil ? @"UIButtonAddPhoto" : @"UIButtonEditPhoto", nil) forState:UIControlStateNormal];
}

- (void)updateRecord
{
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithDictionary:self.record];
    [record setObject:self.nameTextField.text forKey:@"name"];
    [record setObject:self.detailsTextField.text forKey:@"details"];
    
    if (self.productImageView.image != nil)
        [record setObject:[UIImagePNGRepresentation(self.productImageView.image) base64EncodedString] forKey:@"photo"];
    else
        [record setObject:[NSNull null] forKey:@"photo"];
    
    self.record = [record copy];
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([actionSheet tag] == kAddPhotoAlertSheetTag)
    {
        UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
        [imagePickerController setDelegate:self];
        
        if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] == YES)
        {
            if (buttonIndex == 0)
            {
                NSLog(@"TAKE");
            }
            
        }
        else if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] == NO)
        {
            if (buttonIndex == 0)
                [self.navigationController presentViewController:imagePickerController animated:YES completion:nil];
            else if (buttonIndex == 1)
                [self deletePhoto];
        }

    }
    else if ([actionSheet tag] == kDeletePhotoAlertSheetTag)
    {
        if (buttonIndex == 0)
            self.productImageView.image = nil;
    }
    
    [self togglePickerButtonText];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissPicker:picker];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    self.productImageView.image = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    [self.pickerButton setTitle:NSLocalizedString(@"UIButtonEditPhoto", nil) forState:UIControlStateNormal];
    
    [self dismissPicker:picker];
}

#pragma mark - UITextFieldDelegate

- (void)nameTextFieldDidChange:(id)sender
{
    [[[[[self navigationController] navigationBar] topItem] rightBarButtonItem] setEnabled: ! [[self.nameTextField text] isEqualToString:@""]];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self done:self];
    
    return YES;
}

@end
