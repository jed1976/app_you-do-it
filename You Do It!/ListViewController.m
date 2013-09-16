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
@property (nonatomic, strong) NSIndexPath *currentEditIndexPath;
@property (nonatomic, strong) UISegmentedControl *filterControl;
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, strong) NSMutableArray *rawItems;
@property IBOutlet UISearchBar *searchBar;
@property (strong,nonatomic) NSMutableArray *searchResults;
@property (nonatomic) NSInteger selectedFilterSegment;
@property (nonatomic, strong) MSTable *table;
@property (nonatomic, strong) NSString *tableName;

- (void)loadData;

@end

@implementation ListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self playAudioFile:@"You Do It"];
    
    NSBundle *bundle = [NSBundle mainBundle];
    
    self.client = [MSClient clientWithApplicationURL:[NSURL URLWithString:[bundle objectForInfoDictionaryKey:@"MSURL"]] applicationKey:[bundle objectForInfoDictionaryKey:@"MSAppKey"]];
    self.table = [self.client tableWithName:kTableName];
    self.rawItems = [NSMutableArray array];
    self.searchResults = [NSMutableArray array];
    
    self.navigationItem.leftBarButtonItem = [self editButtonItem];
    
    [self addFilterControl];
    
    [self loadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    self.client = nil;
    self.rawItems = nil;
    self.searchResults = nil;
    self.table = nil;
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
    NSDictionary *newItem = @{
                              @"name": @"",
                              @"details": @"",
                              @"created": [NSDate date],
                              @"active": @NO
                            };
    
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

- (void)addFilterControl
{
    self.selectedFilterSegment = 0;
    
    self.filterControl = [[UISegmentedControl alloc] initWithItems:@[@"All", @"Active"]];
    [self.filterControl setSelectedSegmentIndex:self.selectedFilterSegment];
    [self.filterControl addTarget:self action:@selector(toggleFilter:) forControlEvents:UIControlEventValueChanged];
    
    UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithCustomView:self.filterControl];
    UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    self.toolbarItems = @[spaceItem, barButton, spaceItem];
}

- (void)toggleFilter:(id)sender
{
    self.selectedFilterSegment = [sender selectedSegmentIndex];
    [self loadData];
}

- (void)loadData
{
    [self.refreshControl beginRefreshing];
    
    MSQuery *query = nil;
    
    self.filterControl.enabled = NO;
    
    if (self.selectedFilterSegment == 0)
    {
        query = [self.table query];
    }
    else
    {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.active == YES"];
        query = [self.table queryWithPredicate:predicate];
    }
    
    query.fetchLimit = 500;
    
    self.navigationController.navigationBar.topItem.leftBarButtonItem.enabled = NO;
    self.navigationController.navigationBar.topItem.rightBarButtonItem.enabled = NO;
    
    [query readWithCompletion:^(NSArray *items, NSInteger totalCount, NSError *error) {
        if (error != nil)
        {
            [self displayDataReadAlert];
        }
        else
        {
            self.navigationController.navigationBar.topItem.leftBarButtonItem.enabled = YES;
            self.navigationController.navigationBar.topItem.rightBarButtonItem.enabled = YES;
            self.filterControl.enabled = YES;
            
            self.items = (NSMutableArray *)[self partitionObjects:items collationStringSelector:@selector(self)];
            self.rawItems = [items mutableCopy];
            
            [self.tableView reloadData];
        }
        
        [self.refreshControl endRefreshing];
    }];
}

-(void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    self.filterControl.enabled = NO;
    NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"SELF.name contains[cd] %@", searchText];
    self.searchResults = (NSMutableArray *)[self.rawItems filteredArrayUsingPredicate:resultPredicate];
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

- (IBAction)refresh:(id)sender
{
    [self loadData];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];

    [self.navigationController.navigationBar.topItem.rightBarButtonItem setEnabled: ! [self.tableView isEditing]];
}

- (IBAction)switchToggle:(id)sender
{
    UISwitch *switchControl = (UISwitch *)sender;
    UITableView *tableView = self.searchDisplayController.active ? self.searchDisplayController.searchResultsTableView : self.tableView;
    CGRect buttonFrame = [switchControl convertRect:switchControl.bounds toView:tableView];
    NSIndexPath *indexPath = [tableView indexPathForRowAtPoint:buttonFrame.origin];
    self.currentEditIndexPath = indexPath;
    
    NSMutableDictionary *item = nil;
    
    if (self.searchDisplayController.active)
        item = [self.searchResults objectAtIndex:indexPath.row];
    else
        item = [[[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row] mutableCopy];
    
    [item setObject:[NSNumber numberWithBool:switchControl.on] forKey:@"active"];
    
    if ([switchControl isOn])
        [self playAudioFile:@"Oh Yeah"];
    else
        [self playAudioFile:@"You Promised"];
    
    [self.table update:[item copy] completion:^(NSDictionary *item, NSError *error) {
        if (error != nil)
        {
            [self displayDataUpdateAlert];
        }
        else
        {
            if ( ! self.searchDisplayController.active)
                [self loadData];
        }
    }];
}

#pragma mark - UISearchDisplayController Delegate Methods

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterContentForSearchText:searchString
                               scope:[[self.searchDisplayController.searchBar scopeButtonTitles]
                                      objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    
    return YES;
}

- (void)searchDisplayController:(UISearchDisplayController *)controller didLoadSearchResultsTableView:(UITableView *)tableView
{
    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    if ( ! self.searchDisplayController.active)
        [self loadData];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    self.filterControl.enabled = YES;
    [self loadData];
}

#pragma mark - Table view data source

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    return tableView == self.searchDisplayController.searchResultsTableView ? nil : [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return tableView == self.searchDisplayController.searchResultsTableView ? 1 : [[[UILocalizedIndexedCollation currentCollation] sectionTitles] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return tableView == self.searchDisplayController.searchResultsTableView ? [self.searchResults count] : [[self.items objectAtIndex:section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    BOOL showSection = [[self.items objectAtIndex:section] count] != 0;
    
    if (tableView == self.searchDisplayController.searchResultsTableView)
        return nil;
    else
        return (showSection) ? [[[UILocalizedIndexedCollation currentCollation] sectionTitles] objectAtIndex:section] : nil;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return tableView == self.searchDisplayController.searchResultsTableView ? 0 : [[UILocalizedIndexedCollation currentCollation] sectionForSectionIndexTitleAtIndex:index];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    NSDictionary *item = nil;
    
    if (tableView == self.searchDisplayController.searchResultsTableView)
        item = [self.searchResults objectAtIndex:indexPath.row];
    else
        item = [[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    [cell textLabel].text = [item objectForKey:@"name"];
    
    // Temporarily check for NSNull as the previous version of the app did not contain
    // a "details" column and the Azure API return NSNull in such cases.
    [cell detailTextLabel].text = [[item objectForKey:@"details"] isKindOfClass:[NSNull class]] ? @"" : [item objectForKey:@"details"];
    
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
        NSDictionary *item = [[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        
        [self.table delete:item completion:^(NSNumber *itemId, NSError *error) {
            [self playAudioFile:@"No"];            
            [self loadData];
        }];
    }   
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    return ! self.searchDisplayController.active;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.searchDisplayController.active) return;
    
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
