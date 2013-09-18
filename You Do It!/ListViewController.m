//
//  ListViewController.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import "ListViewController.h"

NSString *kSegueShowFormId = @"editItemSegue";
NSString *kSegueShowProductImage = @"productImageSegue";
NSString *kTableName = @"ShoppingList";

@interface ListViewController ()
{
    AVAudioPlayer *audioPlayer;
}

@property (nonatomic, strong) DBAccount *account;
@property (nonatomic, strong) DBRecord *currentRecord;
@property (nonatomic, strong) NSIndexPath *currentEditIndexPath;
@property (nonatomic, strong) UISegmentedControl *filterControl;
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, strong) ProductImageViewController *productImageViewController;
@property (nonatomic, strong) NSMutableArray *rawItems;
@property IBOutlet UISearchBar *searchBar;
@property (nonatomic, strong) NSMutableArray *searchResults;
@property (nonatomic) NSInteger selectedFilterSegment;
@property (nonatomic, strong) DBDatastore *store;
@property (nonatomic, strong) DBTable *table;

- (IBAction)switchToggle:(id)sender;
- (IBAction)refresh:(id)sender;

@end

@implementation ListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self playAudioFile:@"You Do It"];

    self.rawItems = [NSMutableArray array];
    self.searchResults = [NSMutableArray array];
    
    self.navigationItem.leftBarButtonItem = [self editButtonItem];
    
    [self addFilterControl];
    
    self.account = [[DBAccountManager sharedManager] linkedAccount];
    
    if (self.account)
    {
        self.store = [DBDatastore openDefaultStoreForAccount:self.account error:nil];
        self.table = [self.store getTable:kTableName];
        
        [self loadData];
    }
    else
    {
        [[DBAccountManager sharedManager] linkFromController:self];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    self.rawItems = nil;
    self.searchResults = nil;
}

#pragma mark - UIAlert actions

- (void)displayErrorAlert:(DBError *)error
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Error %i", error.code]
                                                    message:[error.userInfo objectForKey:@"NSDebugDescription"]
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:NSLocalizedString(@"UIAlertOKButton", nil), nil];
    [alert show];
}

#pragma mark - Actions

- (IBAction)add:(id)sender
{
    [self disableActionButtons];
    
    DBError *error = nil;
    DBRecord *record = [self.table insert:@{ @"active": @NO, @"created": [NSDate date], @"name": @"", @"details": @"", @"photo": @"" }];
    [self.store sync:&error];
    
    if (error != nil)
    {
        [self displayErrorAlert:error];
    }
    else
    {
        self.currentRecord = record;
        [self performSegueWithIdentifier:kSegueShowFormId sender:self];
        [self enableActionButtons];
    }
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

- (void)disableActionButtons
{
    self.navigationController.navigationBar.topItem.leftBarButtonItem.enabled = NO;
    self.navigationController.navigationBar.topItem.rightBarButtonItem.enabled = NO;
    self.filterControl.enabled = NO;
}

- (void)enableActionButtons
{
    self.navigationController.navigationBar.topItem.leftBarButtonItem.enabled = YES;
    self.navigationController.navigationBar.topItem.rightBarButtonItem.enabled = YES;
    self.filterControl.enabled = YES;
}

- (void)toggleFilter:(id)sender
{
    self.selectedFilterSegment = [sender selectedSegmentIndex];
    [self loadData];
}

- (void)loadData
{
    [self.refreshControl beginRefreshing];

    // BUG: This is due to the tableView being inside a UINavigationController
    if (self.tableView.contentOffset.y == 0)
    {
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^(void) {
            self.tableView.contentOffset = CGPointMake(0, -self.refreshControl.frame.size.height);
        } completion:nil];
    }
    
    [self disableActionButtons];
    
    DBError *error = nil;
    NSArray *items = nil;
    
    if (self.selectedFilterSegment == 0)
        items = [self.table query:nil error:&error];
    else
        items = [self.table query:@{ @"active": @YES } error:&error];
    
    if (error != nil)
    {
        [self displayErrorAlert:error];
    }
    else
    {
        self.items = (NSMutableArray *)[self partitionObjects:items collationStringSelector:@selector(self)];
        self.rawItems = [self.items mutableCopy];
        [self.tableView reloadData];
        
        [self enableActionButtons];
        
        [self.refreshControl endRefreshing];
    }
}

-(void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    [self disableActionButtons];
    
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
    
    if ([segue.identifier isEqualToString:kSegueShowFormId])
    {
        FormViewController *destinationController = [[navigationController childViewControllers] objectAtIndex:0];
        destinationController.delegate = self;
        [destinationController setRecord:self.currentRecord];
    }
    else if ([segue.identifier isEqualToString:kSegueShowProductImage])
    {
        ProductImageViewController *destinationController = [[navigationController childViewControllers] objectAtIndex:0];
        [destinationController setRecord:self.currentRecord];
    }
}

- (IBAction)refresh:(id)sender
{
    [self.tableView reloadData];
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
    
    DBRecord *item = nil;
    DBError *error = nil;
    
    if (self.searchDisplayController.active)
        item = (DBRecord *)[self.searchResults objectAtIndex:indexPath.row];
    else
        item = (DBRecord *)[[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    item[@"active"] = [NSNumber numberWithBool:switchControl.on];
    [self.store sync:&error];
    
    if (error != nil)
    {
        [self displayErrorAlert:error];
    }
    else
    {
        if ([switchControl isOn])
            [self playAudioFile:@"Oh Yeah"];
        else
            [self playAudioFile:@"You Promised"];
    }
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
    [self enableActionButtons];
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
        DBError *error = nil;
        DBRecord *item = (DBRecord *)[[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        [item deleteRecord];
        
        [self.store sync:&error];
        
        if (error != nil)
            [self displayErrorAlert:error];
        else
            [self loadData];
    }
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    return ! self.searchDisplayController.active;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.searchDisplayController.active) return;

    self.currentRecord = (DBRecord *)[[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];

    [self performSegueWithIdentifier:tableView.isEditing ? kSegueShowFormId : kSegueShowProductImage sender:self];
}

#pragma mark - UIAlert

- (void)didFinishEditingForm:(DBRecord *)record
{
    DBError *error = nil;
    [self.store sync:&error];
    
    if (error != nil)
    {
        [self displayErrorAlert:error];
    }
    else
    {
        [self playAudioFile:@"You Do It"];
        [self loadData];
    }
}

- (void)didCancelAddingItem:(DBRecord *)record
{
    DBError *error = nil;
    [record deleteRecord];

    [self.store sync:&error];
    
    if (error != nil)
        [self displayErrorAlert:error];
}

@end
