//
//  ListViewController.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import "ListViewController.h"

NSString *kSegueShowFormId = @"editItemSegue";
NSString *kTableName = @"ShoppingList";

@interface ListViewController ()
{
    AVAudioPlayer *audioPlayer;
}

@property (nonatomic, strong) MSClient *client;
@property (nonatomic, strong) NSDictionary *currentRecord;
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, strong) MSTable *table;
@property (nonatomic, strong) NSString *tableName;

- (void)loadData;

@end

@implementation ListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSBundle *bundle = [NSBundle mainBundle];
    
    [self playAudioFile:@"You Do It"];
    
    self.client = [MSClient clientWithApplicationURL:[NSURL URLWithString:[bundle objectForInfoDictionaryKey:@"MSURL"]] applicationKey:[bundle objectForInfoDictionaryKey:@"MSAppKey"]];
    self.table = [self.client tableWithName:kTableName];
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(loadData) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;
    
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
        [self.navigationController.navigationBar setTintColor:[UIColor orangeColor]];

    self.navigationItem.leftBarButtonItem = [self editButtonItem];
    
    [self loadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    self.table = nil;
    self.client = nil;
}

#pragma mark - UIAlert actions

- (void)displayDataReadAlert
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"UIAlertReadErrorTitle", nil)
                                                    message:NSLocalizedString(@"UIAlertReadErrorMessage", nil)
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:NSLocalizedString(@"UIAlertOKButton", nil), nil];
    [alert show];
}

- (void)displayDataInsertAlert
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"UIAlertInsertErrorTitle", nil)
                                                    message:NSLocalizedString(@"UIAlertInsertErrorMessage", nil)
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:NSLocalizedString(@"UIAlertOKButton", nil), nil];
    [alert show];
}

- (void)displayDataUpdateAlert
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"UIAlertUpdateErrorTitle", nil)
                                                    message:NSLocalizedString(@"UIAlertUpdateErrorMessage", nil)
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:NSLocalizedString(@"UIAlertOKButton", nil), nil];
    [alert show];
}

- (void)displayDataDeleteAlert
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"UIAlertDeleteErrorTitle", nil)
                                                    message:NSLocalizedString(@"UIAlertDeleteErrorMessage", nil)
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:NSLocalizedString(@"UIAlertOKButton", nil), nil];
    [alert show];
}

#pragma mark - Actions

- (IBAction)add:(id)sender
{
    NSDictionary *newItem = @{ @"name": @"", @"created": [NSDate date], @"active": @NO, @"order": @-1 };
    
    [self.table insert:newItem completion:^(NSDictionary *result, NSError *error) {
        if (error != nil)
            [self displayDataInsertAlert];
        
        if (result != nil)
        {
            self.currentRecord = result;
            [self performSegueWithIdentifier:kSegueShowFormId sender:self];
        }
    }];
}

- (void)loadData
{
    MSQuery *query = [self.table query];
    [query orderByAscending:@"order"];
    
    [query readWithCompletion:^(NSArray *items, NSInteger totalCount, NSError *error) {
        if (error != nil)
        {
            [self displayDataReadAlert];
            [self.refreshControl endRefreshing];
        }
        else
        {
            self.items = [items mutableCopy];
            [self.tableView reloadData];
            [self.refreshControl endRefreshing];
        }
    }];
}

- (void)playAudioFile:(NSString *)file
{
    NSURL *url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@.m4a", [[NSBundle mainBundle] resourcePath], file]];
	
	NSError *error;
	audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
	audioPlayer.numberOfLoops = 0;
	
    [audioPlayer play];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    UINavigationController *navigationController = segue.destinationViewController;
    FormViewController *destinationController = [[navigationController childViewControllers] objectAtIndex:0];
    destinationController.delegate = self;
    [destinationController setRecord:self.currentRecord];
}

- (IBAction)switchToggle:(id)sender
{
    UISwitch *switchControl = (UISwitch *)sender;
    CGRect buttonFrame = [switchControl convertRect:switchControl.bounds toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:buttonFrame.origin];
    
    NSMutableDictionary *item = [[self.items objectAtIndex:indexPath.row] mutableCopy];
    [item setObject:[NSNumber numberWithBool:switchControl.on] forKey:@"active"];
    
    if ([switchControl isOn])
        [self playAudioFile:@"Oh Yeah"];
    else
        [self playAudioFile:@"You Promised"];
    
    [self.table update:[item copy] completion:^(NSDictionary *item, NSError *error) {
        if (error != nil)
            [self displayDataUpdateAlert];
        else
            [self loadData];
    }];
}

- (IBAction)toggleEdit:(id)sender
{
    [self.tableView setEditing:! [self.tableView isEditing] animated:YES];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.items count];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return [NSString stringWithFormat:@"%i Items", [self.items count]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSDictionary *item = [self.items objectAtIndex:indexPath.row];

    UILabel *label = (UILabel *)[cell viewWithTag:1];
    label.text = [item objectForKey:@"name"];
    
    UISwitch *switchControl = [[UISwitch alloc] initWithFrame:CGRectZero];
    [switchControl setOn:[[item objectForKey:@"active"] boolValue]];
    [switchControl setOnTintColor:[UIColor orangeColor]];
    [switchControl addTarget:self action:@selector(switchToggle:) forControlEvents:UIControlEventValueChanged];
    [switchControl setTag:2];
    
    cell.accessoryView = switchControl;
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        NSDictionary *item = [self.items objectAtIndex:indexPath.row];
        
        [self.table delete:item completion:^(NSNumber *itemId, NSError *error) {
            [self playAudioFile:@"No"];            
            [self loadData];
        }];
    }   
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.currentRecord = [self.items objectAtIndex:indexPath.row];
    [self performSegueWithIdentifier:kSegueShowFormId sender:self];
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    NSString *stringToMove = [self.items objectAtIndex:fromIndexPath.row];
    [self.items removeObjectAtIndex:fromIndexPath.row];
    [self.items insertObject:stringToMove atIndex:toIndexPath.row];
    
    NSInteger index = 0;
    
    for (NSDictionary *item in self.items)
    {
        NSMutableDictionary *updatedItem = [item mutableCopy];
        [updatedItem setObject:[NSNumber numberWithInt:index] forKey:@"order"];
        
        [self.table update:[updatedItem copy] completion:^(NSDictionary *item, NSError *error) {
            if (error != nil) [self displayDataUpdateAlert];
        }];
        
        index++;
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

#pragma mark - UIAlert

- (void)didFinishEditingForm:(NSDictionary *)record
{
    [self.table update:record completion:^(NSDictionary *item, NSError *error) {
        if (error != nil)
        {
            [self displayDataUpdateAlert];
        }
        else
        {
            [self playAudioFile:@"You Do It"];
            [self loadData];
        }
    }];
    
}

- (void)didCancelAddingItem:(NSDictionary *)record
{
    [self.table delete:record completion:nil];
}

@end
