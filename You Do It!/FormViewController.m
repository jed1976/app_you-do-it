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

@interface FormViewController()

@property (nonatomic) BOOL showingDeleteButton;

@end

@implementation FormViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.showingDeleteButton = NO;
    
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
    
    [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertTakePhoto", nil)];
    [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertChoosePhoto", nil)];

    if (self.productImageView.image != nil)
    {
        self.showingDeleteButton = YES;
        [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertDeletePhoto", nil)];
    }
    
    [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertCancelButton", nil)];
    [actionSheet setCancelButtonIndex:self.showingDeleteButton ? 3 : 2];
    
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

- (void)displayErrorAlert:(DBError *)error
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Error %i", error.code]
                                                    message:[error.userInfo objectForKey:@"NSDebugDescription"]
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:NSLocalizedString(@"UIAlertOKButton", nil), nil];
    [alert show];
}

- (IBAction)done:(id)sender
{
    [self updateRecord];
    [_delegate didFinishEditingForm:self.record];

    [self cancel:self];
}

- (void)loadRecord
{
    self.nameTextField.text = self.record[@"name"];
    self.detailsTextField.text = self.record[@"details"];
    
    if ( ! [self.record[@"photo"] isEqualToString:@""])
    {
        DBError *error = nil;
        DBPath *path = [[DBPath root] childPath:self.record[@"photo"]];
        DBFile *file = [[DBFilesystem sharedFilesystem] openFile:path error:&error];
        
        self.productImageView.image = [[UIImage alloc] initWithData:[file readData:&error]];
    }
}

- (void)togglePickerButtonText
{
    [self.pickerButton setTitle:NSLocalizedString(self.productImageView.image == nil ? @"UIButtonAddPhoto" : @"UIButtonEditPhoto", nil) forState:UIControlStateNormal];
}

- (void)updateRecord
{
    self.record[@"name"] = self.nameTextField.text;
    self.record[@"details"] = self.detailsTextField.text;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([actionSheet tag] == kAddPhotoAlertSheetTag)
    {
        if (self.showingDeleteButton && buttonIndex == 2)
        {
            self.showingDeleteButton = NO;
            [self deletePhoto];
            
            return;
        }
        
        UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
        [imagePickerController setAllowsEditing:YES];
        [imagePickerController setDelegate:self];
        
        if (buttonIndex == 0)
            [imagePickerController setSourceType:UIImagePickerControllerSourceTypeCamera];
        
        [self.navigationController presentViewController:imagePickerController animated:YES completion:nil];
    }
    else if ([actionSheet tag] == kDeletePhotoAlertSheetTag)
    {
        if (buttonIndex == 0)
        {
            [self deletePhotoAtStringPath:self.record[@"photo"]];
        }
    }
    
    [self togglePickerButtonText];
}

- (void)deletePhotoAtStringPath:(NSString *)string
{
    DBError *error = nil;
    DBPath *path = [[DBPath root] initWithString:string];
    [[DBFilesystem sharedFilesystem] deletePath:path error:&error];
    
    if (error != nil)
    {
        [self displayErrorAlert:error];
    }
    else
    {
        self.record[@"photo"] = @"";
        self.productImageView.image = nil;
    }
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissPicker:picker];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    DBError *error = nil;
    
    if ( ! [self.record[@"photo"] isEqualToString:@""])
        [self deletePhotoAtStringPath:self.record[@"photo"]];
    
    UIImage *resizedImage = [[info objectForKey:UIImagePickerControllerEditedImage] imageScaledToFitSize:self.productImageView.frame.size];
    
    DBPath *path = [[DBPath root] childPath:[NSString stringWithFormat:@"image-%@", self.record.recordId]];
    DBFile *file = [[DBFilesystem sharedFilesystem] createFile:path error:nil];
    [file writeData:UIImageJPEGRepresentation(resizedImage, 1.0) error:&error];

    [self dismissPicker:picker];
    
    if (error != nil)
        [self displayErrorAlert:error];
    else
    {
        self.record[@"photo"] = path.name;
        self.productImageView.image = resizedImage;
        [self.pickerButton setTitle:NSLocalizedString(@"UIButtonEditPhoto", nil) forState:UIControlStateNormal];
    }
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
