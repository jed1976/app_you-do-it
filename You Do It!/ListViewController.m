//
//  ListViewController.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import "ListViewController.h"

static CGFloat kDoubleLabelY = 10.0;
static NSInteger kInitialSelectedFilterSegment = 0;
static NSString *kSegueShowFormId = @"editItemSegue";
static CGFloat kSingleLabelY = 20.0;
static NSString *kTableName = @"ShoppingList";
static NSString *kAudioEditingName = @"You Do It";
static NSString *kAudioRemovingName = @"You Promised";
static NSString *kAudioActivatingName = @"Oh Yeah";
static CGFloat kTableFooterViewHeight = 44.0;
static CGFloat kTableRowViewHeight = 64.0;
static NSString *kTableViewCellIdentifier = @"Cell";

@interface ListViewController ()
{
    DBAccount *account;
    DBAccountManager *accountManager;
    AVAudioPlayer *audioPlayer;
    DBRecord *currentRecord;
    DBTable *dataTable;
    UISegmentedControl *filterControl;
    NSMutableArray *items;
    NSMutableArray *rawItems;
    DBDatastore *store;
    CGFloat searchBarYOrigin;
    NSMutableArray *searchResults;
    NSInteger selectedFilterSegment;
    CGPoint tableContentOffset;
}

@property IBOutlet UITableView *tableView;

- (IBAction)search:(id)sender;
- (IBAction)switchToggle:(id)sender;

@end


@implementation ListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    searchResults = [NSMutableArray array];
    
    [self setupFilterControl];
    [self setupTableFooter];
    [self playAudioFile:kAudioEditingName];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    __weak ListViewController *slf = self;
    
    [self.accountManager addObserver:self block:^(DBAccount *account) {
        [slf setupItems];
    }];
    
    [self setupItems];
    
    if (self.searchDisplayController.active)
    {
        [self.searchDisplayController.searchResultsTableView reloadData];
    }
    
    [self.navigationController setToolbarHidden:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [self.accountManager removeObserver:self];

    if (store)
    {
        [store removeObserver:self];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self resignFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    currentRecord = nil;
    searchResults = nil;
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion == UIEventSubtypeMotionShake)
    {
        [self.undoManager undo];
    }
}

#pragma mark - UIAlert actions

- (void)displayErrorAlert:(DBError *)error
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Error %i", error.code]
                                                    message:error.description
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:NSLocalizedString(@"UIAlertOKButton", nil), nil];
    [alert show];
}

#pragma mark - Private Methods

- (DBAccount *)account
{
    return [DBAccountManager sharedManager].linkedAccount;
}

- (DBAccountManager *)accountManager
{
    return [DBAccountManager sharedManager];
}

- (DBDatastore *)store
{
    if ( ! store)
    {
        store = [DBDatastore openDefaultStoreForAccount:self.account error:nil];
    }

    return store;
}

#pragma mark - Actions

- (NSInteger)activeItemCount
{
    return [[NSMutableArray arrayWithArray:[dataTable query:@{ @"active": @YES } error:nil]] count];
}

- (IBAction)search:(id)sender
{
    [self.searchDisplayController.searchBar becomeFirstResponder];
}

-(void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    [searchResults removeAllObjects];

    if ([searchText isEqualToString:@""])
    {
        return;
    }
    
    for (NSArray *section in items)
    {
        for (DBRecord *item in section)
        {
            NSRange nameTextRange = [[item[@"name"] lowercaseString] rangeOfString:[searchText lowercaseString]];
            NSRange detailsTextRange = [[item[@"details"] lowercaseString] rangeOfString:[searchText lowercaseString]];
            
            if (nameTextRange.location != NSNotFound || detailsTextRange.location != NSNotFound)
            {
                [searchResults addObject:item];
            }
        }
    }
}

- (NSArray *)partitionObjects:(NSArray *)array collationStringSelector:(SEL)selector
{
    UILocalizedIndexedCollation *collation = [UILocalizedIndexedCollation currentCollation];
    NSInteger sectionCount = [[collation sectionTitles] count];
    NSMutableArray *unsortedSections = [NSMutableArray arrayWithCapacity:sectionCount];
    
    for (NSInteger i = 0; i < sectionCount; i++)
    {
        [unsortedSections addObject:[NSMutableArray array]];
    }
    
    for (DBRecord *object in array)
    {
        NSInteger index = [collation sectionForObject:[object.fields objectForKey:@"name"] collationStringSelector:selector];
        [[unsortedSections objectAtIndex:index] addObject:object];
    }
    
    NSMutableArray *sections = [NSMutableArray arrayWithCapacity:sectionCount];
    
    for (NSMutableArray *section in unsortedSections)
    {
        NSSortDescriptor *nameSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"fields" ascending:YES comparator:^(DBRecord *obj1, DBRecord *obj2) {
            return [obj1[@"name"] compare:obj2[@"name"]];
        }];
        
        NSSortDescriptor *detailsSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"fields" ascending:YES comparator:^(DBRecord *obj1, DBRecord *obj2) {
            return [obj1[@"details"] compare:obj2[@"details"]];
        }];
        
        [section sortUsingDescriptors:@[nameSortDescriptor, detailsSortDescriptor]];
        [sections addObject:section];
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
    if ([segue.identifier isEqualToString:kSegueShowFormId])
    {
        if (currentRecord == nil)
        {
            currentRecord = [dataTable insert:@{@"active": @NO, @"created": [NSDate date], @"name": @"", @"details": @""}];
        }
        
        FormViewController *destinationController = segue.destinationViewController;
        destinationController.delegate = self;
        [destinationController setRecord:currentRecord];
        
        currentRecord = nil;
    }
}

- (void)setRecord:(DBRecord *)record activeState:(NSNumber *)activeState
{
    record[@"active"] = activeState;
    [self syncStore];
    [self setupItems];
}

- (void)setupFilterControl
{
    selectedFilterSegment = kInitialSelectedFilterSegment;
    
    filterControl = [[UISegmentedControl alloc] initWithItems:@[NSLocalizedString(@"UISegmentedControlItem1", nil), NSLocalizedString(@"UISegmentedControlItem2", nil)]];
    [filterControl addTarget:self action:@selector(toggleFilter:) forControlEvents:UIControlEventValueChanged];
    [filterControl setSelectedSegmentIndex:selectedFilterSegment];

    self.navigationItem.titleView = filterControl;
}

- (void)setupItems
{
    DBError *error;
    
    rawItems = [NSMutableArray array];
    
    if (self.account)
    {
        __weak ListViewController *slf = self;
        dataTable = [self.store getTable:kTableName];
        
        [self.store addObserver:self block:^() {
            if (slf.store.status & (DBDatastoreIncoming | DBDatastoreOutgoing)) {
                [slf syncItems];
            }
        }];
        
        rawItems = [NSMutableArray arrayWithArray:[dataTable query:selectedFilterSegment == 0 ? nil : @{ @"active": @YES } error:&error]];
        
        if (error != nil)
            [self displayErrorAlert:error];
        
        [self syncItems];
    }
    else
    {
        [[DBAccountManager sharedManager] linkFromController:self];
    }
}

- (void)setupTableFooter
{
    UILabel *footerView = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, self.tableView.frame.size.width, kTableFooterViewHeight)];
    [footerView setFont:[UIFont systemFontOfSize:17.0]];
    [footerView setTextAlignment:NSTextAlignmentCenter];
    [footerView setTextColor:[UIColor grayColor]];
    
    self.tableView.tableFooterView = footerView;
}

- (IBAction)switchToggle:(id)sender
{
    UISwitch *switchControl = (UISwitch *)sender;
    UITableView *tableView = self.searchDisplayController.active ? self.searchDisplayController.searchResultsTableView : self.tableView;
    CGRect buttonFrame = [switchControl convertRect:switchControl.bounds toView:tableView];
    NSIndexPath *indexPath = [tableView indexPathForRowAtPoint:buttonFrame.origin];
    
    DBRecord *item = nil;
    
    if (self.searchDisplayController.active)
    {
        item = (DBRecord *)[searchResults objectAtIndex:indexPath.row];
    }
    else
    {
        item = (DBRecord *)[[items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    }
    
    [[self.undoManager prepareWithInvocationTarget:self] setRecord:item activeState:[NSNumber numberWithBool: ! switchControl.on]];
    
    [self setRecord:item activeState:[NSNumber numberWithBool:switchControl.on]];
    
    [self playAudioFile:[switchControl isOn] ? kAudioActivatingName : kAudioRemovingName];
}

- (void)syncItems
{
    if (self.account)
    {
        NSDictionary *changed = [self syncStore];
        [self update:changed];
        [self updateFooterCount];
        [self updateBadgeCount];
    }
    else
    {
        [[DBAccountManager sharedManager] linkFromController:self];        
    }
}

- (NSDictionary *)syncStore
{
    DBError *error;    
    NSDictionary *changes = [self.store sync:&error];
    
    if (error != nil)
    {
        [self displayErrorAlert:error];
    }
    
    return changes;
}

- (void)toggleFilter:(id)sender
{
    selectedFilterSegment = [sender selectedSegmentIndex];
    
    CGPoint currentTableContentOffset = self.tableView.contentOffset;

    [self setupItems];
    
    self.tableView.contentOffset = tableContentOffset;
    tableContentOffset = currentTableContentOffset;
}

- (void)update:(NSDictionary *)changedDict
{
    NSMutableArray *deleted = [NSMutableArray array];
    
    for (NSInteger i = [rawItems count] - 1; i >= 0; i--)
    {
        DBRecord *item = rawItems[i];
        
        if (item.deleted)
        {
            [deleted addObject:[NSIndexPath indexPathForRow:i inSection:0]];
            [rawItems removeObjectAtIndex:i];
        }
    }
    
    NSMutableArray *changed = [NSMutableArray arrayWithArray:[changedDict[kTableName] allObjects]];
    NSMutableArray *updates = [NSMutableArray array];
    
    for (NSInteger i = [changed count] - 1; i >= 0; i--)
    {
        DBRecord *record = changed[i];
        
        if (record.deleted)
        {
            [changed removeObjectAtIndex:i];
        }
        else
        {
            NSUInteger idx = [rawItems indexOfObject:record];
            
            if (idx != NSNotFound)
            {
                [updates addObject:[NSIndexPath indexPathForRow:idx inSection:0]];
                [changed removeObjectAtIndex:i];
            }
        }
    }
    
    [rawItems addObjectsFromArray:changed];
    
    NSMutableArray *inserts = [NSMutableArray array];
    
    for (DBRecord *record in changed)
    {
        NSUInteger idx = [rawItems indexOfObject:record];
        
        [inserts addObject:[NSIndexPath indexPathForRow:idx inSection:0]];
    }
    
    items = (NSMutableArray *)[self partitionObjects:rawItems collationStringSelector:@selector(self)];

    if (self.searchDisplayController.active == NO)
    {
        [self.tableView reloadData];
    }
}

- (void)updateBadgeCount
{
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[self activeItemCount]];
}

- (void)updateFooterCount
{
    UILabel *footerView = (UILabel *)self.tableView.tableFooterView;
    NSString *suffix = rawItems.count == 1 ? NSLocalizedString(@"UITableViewFooterLabelItemSingular", nil) : NSLocalizedString(@"UITableViewFooterLabelItemPlural", nil);
    footerView.text = [NSString stringWithFormat:@"%lu %@", (unsigned long)rawItems.count, suffix];
}

#pragma mark - UISearchDisplayController Delegate Methods

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterContentForSearchText:searchString scope:nil];
    
    return YES;
}

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller
{
    [controller.searchBar setShowsCancelButton:YES];
}

- (void)searchDisplayControllerWillEndSearch:(UISearchDisplayController *)controller
{
    [controller.searchBar setText:@""];
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller
{
    [controller.searchBar setShowsCancelButton:YES];
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
    return tableView == self.searchDisplayController.searchResultsTableView ? [searchResults count] : [[items objectAtIndex:section] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kTableRowViewHeight;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    BOOL showSection = [[items objectAtIndex:section] count] != 0;
    
    if (tableView == self.searchDisplayController.searchResultsTableView)
    {
        return nil;
    }
    else
    {
        return (showSection) ? [[[UILocalizedIndexedCollation currentCollation] sectionTitles] objectAtIndex:section] : nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return tableView == self.searchDisplayController.searchResultsTableView ? 0 : [[UILocalizedIndexedCollation currentCollation] sectionForSectionIndexTitleAtIndex:index];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kTableViewCellIdentifier];
    
    DBRecord *item = nil;
    
    if (tableView == self.searchDisplayController.searchResultsTableView)
    {
        item = (DBRecord *)[searchResults objectAtIndex:indexPath.row];
    }
    else
    {
        item = (DBRecord *)[[items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    }
    
    UISwitch *switchControl = (UISwitch *)[cell.contentView viewWithTag:1];
    [switchControl setOn:[item[@"active"] boolValue]];
    [switchControl setOnTintColor:[UIColor orangeColor]];
    [switchControl addTarget:self action:@selector(switchToggle:) forControlEvents:UIControlEventValueChanged];
    
    UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:2];
    nameLabel.text = item[@"name"];
    
    CGRect nameLabelFrame = nameLabel.frame;
    
    if ([item[@"details"] isEqualToString:@""])
    {
        nameLabelFrame.origin.y = kSingleLabelY;
    }
    else
    {
        nameLabelFrame.origin.y = kDoubleLabelY;
    }
    
    nameLabel.frame = nameLabelFrame;
    
    UILabel *detailLabel = (UILabel *)[cell.contentView viewWithTag:3];
    detailLabel.text = item[@"details"];
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.searchDisplayController.active)
    {
        self.navigationItem.backBarButtonItem.title = NSLocalizedString(@"UINavigationItemSearchTitle", nil);
        currentRecord = [searchResults objectAtIndex:indexPath.row];
    }
    else
    {
        self.navigationItem.backBarButtonItem.title = NSLocalizedString(@"UINavigationItemTitle", nil);
        currentRecord = [[items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    }
    
    [self performSegueWithIdentifier:kSegueShowFormId sender:self];
}

#pragma mark - FormViewControllerDelegate

- (void)didCancelEditingItem:(DBRecord *)record
{
    [record deleteRecord];
    [self syncStore];
    [self playAudioFile:kAudioEditingName];
}

- (void)didFinishEditingItem:(DBRecord *)record
{
    [self syncStore];
}

@end
