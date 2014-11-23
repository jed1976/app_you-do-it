//
//  FormViewController.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2014 Hand Whittled, LLC. All rights reserved.
//

#import "FormViewController.h"

static CGFloat kImageQualityLevel = 0.75f;

enum
{
    NameFieldTag = 1,
    DetailFieldTag = 2
};

enum
{
    AddPhotoAlertSheetTag = 1000,
    DeletePhotoAlertSheetTag = 2000,
    DeleteItemAlertSheetTag = 3000
};

@interface FormViewController()
{
    BOOL deletedItem;
    BOOL showingDeleteButton;
}

@property (nonatomic) DBFile *imageFile;
@property (nonatomic) NSData *imageFileData;
@property (nonatomic) DBPath *imagePath;
@property (nonatomic) IBOutlet UITextField *detailsTextField;
@property (nonatomic) IBOutlet UIImageView *imageView;
@property (nonatomic) UIImage *initialImage;
@property (nonatomic) IBOutlet UITextField *nameTextField;
@property (nonatomic) IBOutlet UIButton *pickerButton;

- (IBAction)addPhoto:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)deleteItem:(id)sender;
- (IBAction)done:(id)sender;

@end


@implementation FormViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self loadItem];
    [self togglePickerButtonText];
    
    // Remove hairline border on toolbar
    [self.navigationController.toolbar setBackgroundImage:[[UIImage alloc] init] forToolbarPosition:UIBarPositionBottom barMetrics:UIBarMetricsDefault];
    [self.navigationController.toolbar setShadowImage:[[UIImage alloc] init] forToolbarPosition:UIBarPositionBottom];
    
    // Add custom actions for editing changes
    [self.nameTextField addTarget:self action:@selector(nameTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self.detailsTextField addTarget:self action:@selector(detailsTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    // Add long press gesture recognizer
    UILongPressGestureRecognizer *gestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    [self.imageView addGestureRecognizer:gestureRecognizer];
    
    self.initialImage = [self.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    self.navigationController.toolbarHidden = NO;
    
    showingDeleteButton = NO;
    deletedItem = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
    if ([self.record[@"name"] isEqualToString:@""])
    {
        [self.nameTextField becomeFirstResponder];        
    }
}

- (void)willMoveToParentViewController:(UIViewController *)parent
{
    if (parent == nil && deletedItem == NO)
    {
        [self done:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    self.detailsTextField = nil;
    self.imageView = nil;
    self.nameTextField = nil;
    self.record = nil;
}

#pragma mark - Actions

- (IBAction)addPhoto:(id)sender
{
    [self.nameTextField resignFirstResponder];
    [self.detailsTextField resignFirstResponder];
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
    actionSheet.delegate = self;
    actionSheet.tag = AddPhotoAlertSheetTag;

    // Button order matters here
    [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertTakePhoto", nil)];
    [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertChoosePhoto", nil)];
    
    if (self.imageView.image != nil)
    {
        showingDeleteButton = YES;
        [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertDeletePhoto", nil)];
    }
    
    [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertCancelButton", nil)];
    actionSheet.cancelButtonIndex = showingDeleteButton ? 3 : 2;
    [actionSheet showInView:self.navigationController.view];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)canPerformAction:(SEL)selector withSender:(id) sender
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    if (selector == @selector(paste:) && pasteboard.pasteboardTypes.count > 0)
    {
        return YES;
    }
    
    if (selector == @selector(delete:) && self.imageFile != nil)
    {
        return YES;
    }
    
    return NO;
}

- (IBAction)cancel:(id)sender
{
    if ([self.nameTextField.text isEqualToString:@""])
    {
        [_delegate didCancelEditingItem:self.record];
    }
    
    // Delay the dismissal so that it gives time for the keyboard to disappear first
    [self.navigationController performSelector:@selector(popToRootViewControllerAnimated:) withObject:[NSNumber numberWithBool:YES] afterDelay:0.5];
}

- (void)delete:(id)sender
{
    [self deletePhoto:nil];
}

- (void)deleteItem:(id)sender
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"UIAlertCancelButton", nil)
                                               destructiveButtonTitle:NSLocalizedString(@"UIAlertDeleteItem", nil)
                                                    otherButtonTitles:nil, nil];
    actionSheet.tag = DeleteItemAlertSheetTag;
    [actionSheet showInView:self.navigationController.view];
}

- (void)deletePhoto:(id)sender
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"UIAlertCancelButton", nil)
                                               destructiveButtonTitle:NSLocalizedString(@"UIAlertDeletePhoto", nil)
                                                    otherButtonTitles:nil, nil];
    actionSheet.tag = DeletePhotoAlertSheetTag;
    [actionSheet showInView:self.navigationController.view];
    
}

- (void)displayErrorAlert:(DBError *)error
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Error %li", (long)error.code]
                                                    message:error.description
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:NSLocalizedString(@"UIAlertOKButton", nil), nil];
    [alert show];
}

- (IBAction)done:(id)sender
{
    [self.view endEditing:YES];
    [_delegate didFinishEditingItem:self.record];
}

- (void)handleAddPhotoAlertResponse:(NSInteger)buttonIndex
{
    if (showingDeleteButton && buttonIndex == 3)
    {
        return;
    }
    
    if (showingDeleteButton == NO && buttonIndex == 2)
    {
        return;
    }
    
    if (showingDeleteButton && buttonIndex == 2)
    {
        showingDeleteButton = NO;
        [self deletePhoto:nil];
        
        return;
    }
    
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.allowsEditing = YES;
    imagePickerController.delegate = self;
    
    if (buttonIndex == 0)
    {
        imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    }
    
    [self.navigationController presentViewController:imagePickerController animated:YES completion:nil];
}

- (void)handleDeletePhotoAlertResponse:(NSInteger)buttonIndex
{
    if (buttonIndex == 0)
    {
        [[DBFilesystem sharedFilesystem] deletePath:self.imagePath error:nil];
        self.imageView.image = self.initialImage;
    }
}

- (void)handleDeleteItemAlertResponse:(NSInteger)buttonIndex
{
    if (buttonIndex == 0)
    {
        deletedItem = YES;
        [_delegate didCancelEditingItem:self.record];
        [self cancel:nil];
    }
}

- (void)loadImageInBackground:(id)sender
{
    self.imageFile = [[DBFilesystem sharedFilesystem] openFile:self.imagePath error:nil];
    self.imageFileData = [self.imageFile readData:nil];
    [self performSelectorOnMainThread:@selector(updateImageOnMainThread:) withObject:self waitUntilDone:NO];
}

- (void)loadItem
{
    self.detailsTextField.text = self.record[@"details"];
    self.nameTextField.text = self.record[@"name"];
    self.imageView.image = self.initialImage;
    
    self.imagePath = [[DBPath root] childPath:self.record.recordId];
    DBFileInfo *fileInfo = [[DBFilesystem sharedFilesystem] fileInfoForPath:self.imagePath error:nil];
    
    if (fileInfo != nil)
    {
        [self performSelectorInBackground:@selector(loadImageInBackground:) withObject:self];
    }
}

- (void)longPress:(UILongPressGestureRecognizer *) gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        CGPoint location = [gestureRecognizer locationInView:[gestureRecognizer view]];
        UIMenuController *menuController = [UIMenuController sharedMenuController];
        NSAssert([self becomeFirstResponder], nil, self);
        [menuController setMenuVisible:YES animated:YES];
        [menuController setTargetRect:CGRectMake(location.x, location.y, 0.0, 0.0) inView:[gestureRecognizer view]];
    }
}

- (void)paste:(id)sender
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    if (pasteboard.image != nil)
    {
        [self resizeAndSaveImage:pasteboard.image];
    }
}

- (void)resizeAndSaveImage:(UIImage *)image
{
    UIImage *resizedImage = [image imageScaledToFitSize:self.imageView.frame.size];
    self.imageView.image = resizedImage;
    
    if (self.imageFile == nil)
    {
        self.imageFile = [[DBFilesystem sharedFilesystem] createFile:self.imagePath error:nil];
    }
    
    [self.imageFile writeData:UIImageJPEGRepresentation(resizedImage, kImageQualityLevel) error:nil];
}

- (void)togglePickerButtonText
{
    [self.pickerButton setTitle:NSLocalizedString(self.imageView.image == nil ? @"UIButtonAddPhoto" : @"UIButtonEditPhoto", nil) forState:UIControlStateNormal];
}

- (void)updateImageOnMainThread:(id)sender
{
    if (self.imageFileData == nil)
    {
        return;
    }
    
    UIImage *photo = [[UIImage alloc] initWithData:self.imageFileData];
    self.imageView.image = photo;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (actionSheet.tag)
    {
        case AddPhotoAlertSheetTag:
            [self handleAddPhotoAlertResponse:buttonIndex];
        break;
            
        case DeletePhotoAlertSheetTag:
            [self handleDeletePhotoAlertResponse:buttonIndex];
        break;
            
        case DeleteItemAlertSheetTag:
            [self handleDeleteItemAlertResponse:buttonIndex];
        break;
    }
    
    [self togglePickerButtonText];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self resizeAndSaveImage:[info objectForKey:UIImagePickerControllerEditedImage]];
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self.pickerButton setTitle:NSLocalizedString(@"UIButtonEditPhoto", nil) forState:UIControlStateNormal];
}

#pragma mark - UITextFieldDelegate

- (void)nameTextFieldDidChange:(id)sender
{
    self.record[@"name"] = self.nameTextField.text;
}

- (void)detailsTextFieldDidChange:(id)sender
{
    self.record[@"details"] = self.detailsTextField.text;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    
    if (textField.tag == NameFieldTag)
    {
        [self.detailsTextField becomeFirstResponder];
    }
    
    return YES;
}

@end