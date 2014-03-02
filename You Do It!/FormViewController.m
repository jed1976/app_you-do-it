//
//  FormViewController.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import "FormViewController.h"

static NSInteger kAddPhotoAlertSheetTag = 1000;
static NSInteger kDeletePhotoAlertSheetTag = 2000;
static CGFloat kImageQualityLevel = 0.75;

@interface FormViewController()
{
    BOOL showingDeleteButton;
}

@property (nonatomic) IBOutlet UISwitch *activeSwitch;
@property (nonatomic) IBOutlet UITextField *detailsTextField;
@property (nonatomic) IBOutlet UITextField *nameTextField;
@property (nonatomic) IBOutlet UIButton *pickerButton;
@property (nonatomic) IBOutlet UIImageView *imageView;

- (IBAction)addPhoto:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;
- (IBAction)switchToggle:(id)sender;

@end


@implementation FormViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setDoneButtonState];
    [self loadRecord];
    [self togglePickerButtonText];
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    
    [self.nameTextField addTarget:self action:@selector(nameTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self.detailsTextField addTarget:self action:@selector(detailsTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    UILongPressGestureRecognizer *gestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    [self.view addGestureRecognizer:gestureRecognizer];
    
    showingDeleteButton = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self.nameTextField becomeFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    self.activeSwitch = nil;
    self.detailsTextField = nil;
    self.imageView = nil;
    self.nameTextField = nil;
    self.record = nil;
}

#pragma mark - Actions

- (IBAction)addPhoto:(id)sender
{
    [self.view endEditing:YES];
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
    [actionSheet setDelegate:self];
    [actionSheet setTag:kAddPhotoAlertSheetTag];

    // Button order matters here
    [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertTakePhoto", nil)];
    [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertChoosePhoto", nil)];
    
    if (self.imageView.image != nil)
    {
        showingDeleteButton = YES;
        [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertDeletePhoto", nil)];
    }
    
    [actionSheet addButtonWithTitle:NSLocalizedString(@"UIAlertCancelButton", nil)];
    [actionSheet setCancelButtonIndex:showingDeleteButton ? 3 : 2];
    [actionSheet showInView:self.navigationController.view];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)canPerformAction:(SEL)selector withSender:(id) sender
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    if (selector == @selector(paste:) && [pasteboard pasteboardTypes].count > 0) return YES;
    
    if (selector == @selector(delete:) && self.record[@"photoData"] != nil) return YES;
    
    return NO;
}

- (IBAction)cancel:(id)sender
{
    [self.view endEditing:YES];

    if ([[self.nameTextField text] isEqualToString:@""])
        [_delegate didCancelEditingItem:self.record];
    
    // Delay the dismissal so that it gives time for the keyboard to disappear first
    [self performSelector:@selector(dismissModalViewControllerAnimated:) withObject:self.presentingViewController afterDelay:0.5];
}

- (void)delete:(id)sender
{
    [self deletePhoto];
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
                                                    message:error.description
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
    self.activeSwitch.on = [self.record[@"active"] boolValue];
    self.detailsTextField.text = self.record[@"details"];
    self.imageView.image = [[UIImage alloc] initWithData:self.record[@"photoData"]];
    self.nameTextField.text = self.record[@"name"];
}

- (void)longPress:(UILongPressGestureRecognizer *) gestureRecognizer
{
    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan)
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
        [self resizeAndSaveImage:pasteboard.image];
}

- (void)resizeAndSaveImage:(UIImage *)image
{
    UIImage *resizedImage = [image imageScaledToFitSize:self.imageView.frame.size];
    self.imageView.image = resizedImage;
    self.record[@"photoData"] = UIImageJPEGRepresentation(resizedImage, kImageQualityLevel);
}

- (void)setDoneButtonState
{
    self.navigationController.navigationBar.topItem.rightBarButtonItem.enabled = ! [self.record[@"name"] isEqualToString:@""];
}

- (void)togglePickerButtonText
{
    [self.pickerButton setTitle:NSLocalizedString(self.imageView.image == nil ? @"UIButtonAddPhoto" : @"UIButtonEditPhoto", nil)
                       forState:UIControlStateNormal];
}

- (IBAction)switchToggle:(id)sender
{
    self.record[@"active"] = [NSNumber numberWithBool:[(UISwitch *)sender isOn]];
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([actionSheet tag] == kAddPhotoAlertSheetTag)
    {
        if (showingDeleteButton && buttonIndex == 3)
            return;
        
        if ( ! showingDeleteButton && buttonIndex == 2)
            return;
        
        if (showingDeleteButton && buttonIndex == 2)
        {
            showingDeleteButton = NO;
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
            [self.record removeObjectForKey:@"photoData"];
            self.imageView.image = nil;
        }
        
        [self.nameTextField becomeFirstResponder];
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
    [self resizeAndSaveImage:[info objectForKey:UIImagePickerControllerEditedImage]];
    [self dismissPicker:picker];
    [self.pickerButton setTitle:NSLocalizedString(@"UIButtonEditPhoto", nil) forState:UIControlStateNormal];
}

#pragma mark - UITextFieldDelegate

- (void)nameTextFieldDidChange:(id)sender
{
    self.navigationItem.title = self.nameTextField.text;
    self.record[@"name"] = self.nameTextField.text;
    [self setDoneButtonState];
}

- (void)detailsTextFieldDidChange:(id)sender
{
    self.record[@"details"] = self.detailsTextField.text;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self done:self];
    
    return YES;
}

@end