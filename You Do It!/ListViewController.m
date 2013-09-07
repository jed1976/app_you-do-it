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
    NSDictionary *newItem = @{ @"name": @"", @"created": [NSDate date], @"active": @NO };
    
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
            self.items = (NSMutableArray *)[self partitionObjects:items collationStringSelector:@selector(self)];
            [self.tableView reloadData];
            [self.refreshControl endRefreshing];
        }
    }];
}

-(NSArray *)partitionObjects:(NSArray *)array collationStringSelector:(SEL)selector
{
    UILocalizedIndexedCollation *collation = [UILocalizedIndexedCollation currentCollation];
    NSInteger sectionCount = [[collation sectionTitles] count];
    NSMutableArray *unsortedSections = [NSMutableArray arrayWithCapacity:sectionCount];
    
    for (NSInteger i = 0; i < sectionCount; i++)
    {
        [unsortedSections addObject:[NSMutableArray array]];
    }
    
    for (id object in array)
    {
        NSInteger index = [collation sectionForObject:[object objectForKey:@"name"] collationStringSelector:selector];
        [[unsortedSections objectAtIndex:index] addObject:object];
    }
    
    NSMutableArray *sections = [NSMutableArray arrayWithCapacity:sectionCount];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    
    for (NSMutableArray *section in unsortedSections)
    {
        NSMutableArray *sortedArray = [[section sortedArrayUsingDescriptors:sortDescriptors] mutableCopy];
        [sections addObject:sortedArray];
    }
    
    return sections;
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
    
    NSMutableDictionary *item = [[[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row] mutableCopy];
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

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    return [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[[UILocalizedIndexedCollation currentCollation] sectionTitles] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self.items objectAtIndex:section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    BOOL showSection = [[self.items objectAtIndex:section] count] != 0;
    
    return (showSection) ? [[[UILocalizedIndexedCollation currentCollation] sectionTitles] objectAtIndex:section] : nil;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return [[UILocalizedIndexedCollation currentCollation] sectionForSectionIndexTitleAtIndex:index];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSDictionary *item = [[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
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
    self.currentRecord = [[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    [self performSegueWithIdentifier:kSegueShowFormId sender:self];
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
