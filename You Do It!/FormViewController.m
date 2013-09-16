//
//  FormViewController.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import "FormViewController.h"

@interface FormViewController ()

@end

@implementation FormViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[[[[self navigationController] navigationBar] topItem] rightBarButtonItem] setEnabled:[[self.nameTextField text] isEqualToString:@""]];
    
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
        [self.navigationController.navigationBar setTintColor:[UIColor orangeColor]];
    
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
    
    [self.nameTextField setText:[self.record valueForKey:@"name"]];
    [self.nameTextField addTarget:self action:@selector(nameTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self.nameTextField becomeFirstResponder];
    
    [self.detailsTextField setText:[[self.record valueForKey:@"details"] isKindOfClass:[NSNull class]] ? @"" : [self.record valueForKey:@"details"]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Actions

- (IBAction)cancel:(id)sender
{
    if ([[self.nameTextField text] isEqualToString:@""])
        [_delegate didCancelAddingItem:self.record];
    
    [self.nameTextField resignFirstResponder];
    [self.detailsTextField resignFirstResponder];
    
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)done:(id)sender
{
    NSMutableDictionary *updatedRecord = [NSMutableDictionary dictionaryWithDictionary:self.record];
    [updatedRecord setObject:self.nameTextField.text forKey:@"name"];
    [updatedRecord setObject:self.detailsTextField.text forKey:@"details"];
    [_delegate didFinishEditingForm:updatedRecord];
    [self cancel:self];      
}

#pragma mark - UITextFieldDelegate

- (void)nameTextFieldDidChange:(id)sender
{
    [[[[[self navigationController] navigationBar] topItem] rightBarButtonItem] setEnabled:! [[self.nameTextField text] isEqualToString:@""]];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self done:self];
    
    return YES;
}

@end
