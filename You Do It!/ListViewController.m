//
//  ListViewController.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import "ListViewController.h"
#import "Dropbox/Dropbox.h"

static NSString *kAudioActivatingName = @"Oh Yeah";
static NSString *kAudioEditingName = @"You Do It";
static NSString *kAudioRemovingName = @"You Promised";
static CGFloat kDoubleLabelY = 10.0;
static NSInteger kInitialSelectedFilterSegment = 0;
static NSString *kSegueShowFormId = @"editItemSegue";
static CGFloat kSingleLabelY = 20.0;
static CGFloat kTableFooterViewHeight = 44.0;
static NSString *kTableName = @"ShoppingList";
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
    
    __weak ListViewController *_self = self;
    
    [self.accountManager addObserver:self block:^(DBAccount *account) {
        [_self setupItems];
    }];
    
    [self setupItems];
    
    self.navigationController.toolbarHidden = YES;
    self.tableView.editing = YES;
    
    if (self.searchDisplayController.active)
    {
        [self.searchDisplayController.searchResultsTableView reloadData];
    }
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
    return DBAccountManager.sharedManager.linkedAccount;
}

- (DBAccountManager *)accountManager
{
    return DBAccountManager.sharedManager;
}

- (DBDatastore *)store
{
    if (store == NO)
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
    UILocalizedIndexedCollation *collation = UILocalizedIndexedCollation.currentCollation;
    NSInteger sectionCount = [collation.sectionTitles count];
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
    NSURL *url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@.m4a", [NSBundle.mainBundle resourcePath], file]];
	
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

- (IBAction)search:(id)sender
{
    [self.searchDisplayController.searchBar becomeFirstResponder];
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
    filterControl.selectedSegmentIndex = selectedFilterSegment;
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
            if (slf.store.status & (DBDatastoreIncoming | DBDatastoreOutgoing))
            {
                [slf syncItems];
            }
        }];
        
        rawItems = [NSMutableArray arrayWithArray:[dataTable query:selectedFilterSegment == 0 ? nil : @{ @"active": @YES } error:&error]];
        
        if (error != nil)
        {
            [self displayErrorAlert:error];
        }
        
        [self syncItems];
    }
    else
    {
        [DBAccountManager.sharedManager linkFromController:self];
    }
}

- (void)setupTableFooter
{
    UILabel *footerView = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, self.tableView.frame.size.width, kTableFooterViewHeight)];
    footerView.font = [UIFont systemFontOfSize:17.0];
    footerView.textAlignment = NSTextAlignmentCenter;
    footerView.textColor = [UIColor grayColor];
    
    self.tableView.tableFooterView = footerView;
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
        [DBAccountManager.sharedManager linkFromController:self];
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
    [UIApplication.sharedApplication setApplicationIconBadgeNumber:[self activeItemCount]];
}

- (void)updateFooterCount
{
    UILabel *footerView = (UILabel *)self.tableView.tableFooterView;
    NSString *suffix = rawItems.count == 1 ? NSLocalizedString(@"UITableViewFooterLabelItemSingular", nil) : NSLocalizedString(@"UITableViewFooterLabelItemPlural", nil);
    footerView.text = [NSString stringWithFormat:@"%lu %@", (unsigned long)rawItems.count, suffix];
}

- (void)viewItem:(id)sender
{
    UIButton *disclosureButton = (UIButton *)sender;
    UITableView *tableView = self.searchDisplayController.active ? self.searchDisplayController.searchResultsTableView : self.tableView;
    CGRect buttonFrame = [disclosureButton convertRect:disclosureButton.bounds toView:tableView];
    NSIndexPath *indexPath = [tableView indexPathForRowAtPoint:buttonFrame.origin];
    
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

#pragma mark - UISearchDisplayController Delegate Methods

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterContentForSearchText:searchString scope:nil];
    
    return YES;
}

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller
{
    controller.searchResultsTableView.allowsMultipleSelectionDuringEditing = YES;
    controller.searchResultsTableView.editing = YES;
    controller.searchBar.showsCancelButton = YES;
}

- (void)searchDisplayControllerWillEndSearch:(UISearchDisplayController *)controller
{
    controller.searchBar.text = @"";
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller
{
    controller.searchBar.showsCancelButton = YES;
}

#pragma mark - Table view data source

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    return tableView == self.searchDisplayController.searchResultsTableView ? nil : [UILocalizedIndexedCollation.currentCollation sectionIndexTitles];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return tableView == self.searchDisplayController.searchResultsTableView ? 1 : [UILocalizedIndexedCollation.currentCollation sectionTitles].count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Re-fetch the search results
    if (self.searchDisplayController.searchResultsTableView)
    {
        [self.searchDisplayController.delegate searchDisplayController:self.searchDisplayController shouldReloadTableForSearchString:self.searchDisplayController.searchBar.text];
    }
    
    return tableView == self.searchDisplayController.searchResultsTableView ? searchResults.count : [[items objectAtIndex:section] count];
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
        return (showSection) ? [[UILocalizedIndexedCollation.currentCollation sectionTitles] objectAtIndex:section] : nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return tableView == self.searchDisplayController.searchResultsTableView ? 0 : [UILocalizedIndexedCollation.currentCollation sectionForSectionIndexTitleAtIndex:index];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kTableViewCellIdentifier];
    
    // Get item
    DBRecord *item = (tableView == self.searchDisplayController.searchResultsTableView)
        ? [searchResults objectAtIndex:indexPath.row]
        : [[items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    // Add disclosure button that covers the entire cell content view
    UIButton *contentViewDisclosureButton = [[UIButton alloc] initWithFrame:cell.contentView.frame];
    [contentViewDisclosureButton addTarget:self action:@selector(viewItem:) forControlEvents:UIControlEventTouchUpInside];
    [cell.contentView addSubview:contentViewDisclosureButton];

    // Name label
    cell.textLabel.text = item[@"name"];
    CGRect nameLabelFrame = cell.textLabel.frame;
    nameLabelFrame.origin.y = [item[@"details"] isEqualToString:@""] ? kSingleLabelY : kDoubleLabelY;
    cell.textLabel.frame = nameLabelFrame;
    
    // Detail label
    cell.detailTextLabel.text = item[@"details"];
    
    // Set checkmark state
    if ([item[@"active"] boolValue])
    {
        [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
    else
    {
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    DBRecord *item = (self.searchDisplayController.active)
        ? [searchResults objectAtIndex:indexPath.row]
        : [[items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    [self setRecord:item activeState:[NSNumber numberWithBool:NO]];
    [self playAudioFile:kAudioRemovingName];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    DBRecord *item = (self.searchDisplayController.active)
    ? [searchResults objectAtIndex:indexPath.row]
    : [[items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    [self setRecord:item activeState:[NSNumber numberWithBool:YES]];
    [self playAudioFile:kAudioActivatingName];
}

#pragma mark - FormViewControllerDelegate

- (void)didCancelEditingItem:(DBRecord *)record
{
    [record deleteRecord];
    [self syncStore];
}

- (void)didFinishEditingItem:(DBRecord *)record
{
    [self syncStore];
}

@end
