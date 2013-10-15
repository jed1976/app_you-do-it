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

@property (nonatomic) IBOutlet UISwitch *activeSwitch;
@property (nonatomic) IBOutlet UITextField *detailsTextField;
@property (nonatomic) IBOutlet UITextField *nameTextField;
@property (nonatomic) IBOutlet UIButton *pickerButton;
@property (nonatomic) IBOutlet UIImageView *productImageView;
@property (nonatomic) BOOL showingDeleteButton;

- (IBAction)addPhoto:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;
- (IBAction)switchToggle:(id)sender;

@end

@implementation FormViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.showingDeleteButton = NO;
    
    [[[[[self navigationController] navigationBar] topItem] rightBarButtonItem] setEnabled: ! [self.record[@"name"] isEqualToString:@""]];

    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
        [self.navigationController.navigationBar setTintColor:[UIColor orangeColor]];
    
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];

    [self loadRecord];
    
    [self.nameTextField addTarget:self action:@selector(nameTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    [self.detailsTextField addTarget:self action:@selector(detailsTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    UILongPressGestureRecognizer *gr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    [self.view addGestureRecognizer:gr];
 
    [self togglePickerButtonText];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self.nameTextField becomeFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    self.record = nil;
    self.nameTextField = nil;
    self.detailsTextField = nil;
    self.activeSwitch = nil;
    self.productImageView = nil;
}

#pragma mark - Actions

- (IBAction)addPhoto:(id)sender
{
    [self.nameTextField resignFirstResponder];
    [self.detailsTextField resignFirstResponder];
    
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
    [self.nameTextField resignFirstResponder];
    [self.detailsTextField resignFirstResponder];

    if ([[self.nameTextField text] isEqualToString:@""])
        [_delegate didCancelEditingItem:self.record];
    
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
    self.nameTextField.text = self.record[@"name"];
    self.detailsTextField.text = self.record[@"details"];
    self.activeSwitch.on = [self.record[@"active"] boolValue];
    self.productImageView.image = self.record[@"photoData"] ? [[UIImage alloc] initWithData:self.record[@"photoData"]] : nil;
}

- (void)longPress:(UILongPressGestureRecognizer *) gestureRecognizer
{
    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan)
    {
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
    
    if (pasteboard.image == nil) return;

    UIImage *image = [pasteboard.image imageScaledToFitSize:self.productImageView.frame.size];
    
    self.record[@"photoData"] = UIImageJPEGRepresentation(image, kImageQualityLevel);
    self.productImageView.image = image;
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
        {
            [self.record removeObjectForKey:@"photoData"];
            self.productImageView.image = nil;
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
    UIImage *resizedImage = [[info objectForKey:UIImagePickerControllerEditedImage] imageScaledToFitSize:self.productImageView.frame.size];

    self.productImageView.image = resizedImage;
    self.record[@"photoData"] = UIImageJPEGRepresentation(resizedImage, kImageQualityLevel);

    [self dismissPicker:picker];
    
    [self.pickerButton setTitle:NSLocalizedString(@"UIButtonEditPhoto", nil) forState:UIControlStateNormal];
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
    self.record[@"details"] = self.detailsTextField.text;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self done:self];
    
    return YES;
}

@end
