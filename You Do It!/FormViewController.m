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
CGFloat kImageQualityLevel = 0.75;

@interface FormViewController()

@property (nonatomic) BOOL showingDeleteButton;

- (IBAction)switchToggle:(id)sender;

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
    
    [self.detailsTextField addTarget:self action:@selector(detailsTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    UILongPressGestureRecognizer *gr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    [self.view addGestureRecognizer:gr];
 
    [self togglePickerButtonText];
}

- (void)longPress:(UILongPressGestureRecognizer *) gestureRecognizer {
    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan) {
        CGPoint location = [gestureRecognizer locationInView:[gestureRecognizer view]];
        UIMenuController *menuController = [UIMenuController sharedMenuController];
        NSAssert([self becomeFirstResponder], @"Sorry, UIMenuController will not work with %@ since it cannot become first responder", self);
        [menuController setTargetRect:CGRectMake(location.x, location.y, 0.0f, 0.0f) inView:[gestureRecognizer view]];
        [menuController setMenuVisible:YES animated:YES];
    }
}

- (void)paste:(id)sender
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    if ([pasteboard pasteboardTypes].count == 0) return;
    
    NSData *data = [pasteboard dataForPasteboardType:[[pasteboard pasteboardTypes] lastObject]];
    UIImage *image = [[[UIImage alloc] initWithData:data] imageScaledToFitSize:self.productImageView.frame.size];
    
    if ([self saveImage:image])
    {
        self.productImageView.image = image;
        [self.nameTextField becomeFirstResponder];
    }
}

- (void)delete:(id)sender
{
    [self deletePhoto];
}

- (BOOL)canPerformAction:(SEL)selector withSender:(id) sender
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];

    if (selector == @selector(paste:) && [pasteboard pasteboardTypes].count > 0) return YES;
    
    if (selector == @selector(delete:) && ! [self.record[@"photo"] isEqualToString:@""]) return YES;
    
    return NO;
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
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
        [_delegate didCancelEditingItem:self.record];
    
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
    [_delegate didFinishEditingItem:self.record];

    [self cancel:self];
}

- (void)loadRecord
{
    self.navigationItem.title = self.record[@"name"];
    
    if ( ! [self.record[@"details"] isEqualToString:@""])
        self.navigationItem.prompt = self.record[@"details"];
    
    self.nameTextField.text = self.record[@"name"];
    self.detailsTextField.text = self.record[@"details"];
    self.activeSwitch.on = [self.record[@"active"] boolValue];
    
    if ( ! [self.record[@"photo"] isEqualToString:@""])
    {
        DBError *error;
        DBPath *path = [[DBPath root] childPath:self.record[@"photo"]];
        DBFile *file = [[DBFilesystem sharedFilesystem] openFile:path error:&error];
        
        self.productImageView.image = [[UIImage alloc] initWithData:[file readData:&error]];
    }
}

- (void)togglePickerButtonText
{
    [self.pickerButton setTitle:NSLocalizedString(self.productImageView.image == nil ? @"UIButtonAddPhoto" : @"UIButtonEditPhoto", nil) forState:UIControlStateNormal];
}

- (IBAction)switchToggle:(id)sender
{
    UISwitch *switchControl = (UISwitch *)sender;
    self.record[@"active"] = [NSNumber numberWithBool:[switchControl isOn]];
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([actionSheet tag] == kAddPhotoAlertSheetTag)
    {
        if ((self.showingDeleteButton && buttonIndex == 3) || (! self.showingDeleteButton && buttonIndex == 2)) return;
        
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
            [self deletePhotoAtStringPath:self.record[@"photo"]];
        
        [self.nameTextField becomeFirstResponder];
    }
    
    [self togglePickerButtonText];
}

- (void)deletePhotoAtStringPath:(NSString *)string
{
    DBError *error;
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
    if ( ! [self.record[@"photo"] isEqualToString:@""])
        [self deletePhotoAtStringPath:self.record[@"photo"]];
    
    UIImage *resizedImage = [[info objectForKey:UIImagePickerControllerEditedImage] imageScaledToFitSize:self.productImageView.frame.size];

    if ([self saveImage:resizedImage])
    {
        [self dismissPicker:picker];
        self.productImageView.image = resizedImage;
        [self.pickerButton setTitle:NSLocalizedString(@"UIButtonEditPhoto", nil) forState:UIControlStateNormal];
    }
}

- (BOOL)saveImage:(UIImage *)image
{
    DBError *error;
    DBPath *path = [[DBPath root] childPath:[NSString stringWithFormat:@"image-%@.jpg", self.record.recordId]];
    DBFile *file = [[DBFilesystem sharedFilesystem] createFile:path error:nil];
    [file writeData:UIImageJPEGRepresentation(image, kImageQualityLevel) error:&error];
    
    if (error != nil)
    {
        [self displayErrorAlert:error];
        return NO;
    }
    else
    {
        self.record[@"photo"] = path.name;
        return YES;
    }
}

#pragma mark - UITextFieldDelegate

- (void)nameTextFieldDidChange:(id)sender
{
    [[[[[self navigationController] navigationBar] topItem] rightBarButtonItem] setEnabled: ! [[self.nameTextField text] isEqualToString:@""]];
    
    self.navigationItem.title = self.nameTextField.text;
    self.record[@"name"] = self.nameTextField.text;
}

- (void)detailsTextFieldDidChange:(id)sender
{
    if ( ! [self.detailsTextField.text isEqualToString:@""])
        self.navigationItem.prompt = self.detailsTextField.text;
    
    self.record[@"details"] = self.detailsTextField.text;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self done:self];
    
    return YES;
}

@end
