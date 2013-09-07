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
    
    [self.requiredTextField setText:[self.record valueForKey:@"name"]];
    [self.requiredTextField addTarget:self action:@selector(requiredTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self.requiredTextField becomeFirstResponder];
    
    [[[[[self navigationController] navigationBar] topItem] rightBarButtonItem] setEnabled:! [[self.requiredTextField text] isEqualToString:@""]];
    
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
        [self.navigationController.navigationBar setTintColor:[UIColor orangeColor]];
    
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Actions

- (IBAction)cancel:(id)sender
{
    if ([[self.requiredTextField text] isEqualToString:@""])
        [_delegate didCancelAddingItem:self.record];
    
    [self.requiredTextField resignFirstResponder];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)done:(id)sender
{
    NSMutableDictionary *updatedRecord = [NSMutableDictionary dictionaryWithDictionary:self.record];
    [updatedRecord setObject:self.requiredTextField.text forKey:@"name"];
    [_delegate didFinishEditingForm:updatedRecord];
    [self cancel:self];      
}

#pragma mark - UITextFieldDelegate

- (void)requiredTextFieldDidChange:(id)sender
{
    [[[[[self navigationController] navigationBar] topItem] rightBarButtonItem] setEnabled:! [[self.requiredTextField text] isEqualToString:@""]];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self done:self];
    
    return YES;
}

@end
