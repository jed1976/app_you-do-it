//
//  ListViewController.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import "ListViewController.h"

static NSInteger kInitialSelectedFilterSegment = 0;
static NSString *kSegueShowFormId = @"editItemSegue";
static NSString *kSegueShowProductImage = @"productImageSegue";
static NSString *kTableName = @"ShoppingList";
static NSString *kAudioEditingName = @"You Do It";
static NSString *kAudioRemovingName = @"You Promised";
static NSString *kAudioActivatingName = @"Oh Yeah";
static CGFloat kSearchResultsAnimationDuration = 0.25;
static CGFloat kTableFooterViewHeight = 44.0;
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
    CGFloat searchBarPortraitY;
    CGFloat searchBarLandscapeY;
    CGFloat searchBarYOrigin;
    NSMutableArray *searchResults;
    NSInteger selectedFilterSegment;
    CGPoint tableContentOffset;
    CGFloat tableViewYOrigin;
}

@property IBOutlet UISearchBar *searchBar;
@property IBOutlet UITableView *tableView;

- (IBAction)switchToggle:(id)sender;

@end


@implementation ListViewController

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.leftBarButtonItem = [self editButtonItem];
    self.navigationItem.title = NSLocalizedString(@"UINavigationItemTitle", nil);
    tableContentOffset = CGPointZero;
    
    searchBarPortraitY = floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1 ? 0.0 : 64.0;
    searchBarLandscapeY = floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1 ? 0.0 : 52.0;
    
    [self setupFilterControl];
    [self setupTableFooter];
    [self playAudioFile:kAudioEditingName];
    
    searchResults = [NSMutableArray array];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    __weak ListViewController *slf = self;
    
    [self.accountManager addObserver:self block:^(DBAccount *account) {
        [slf setupItems];
    }];
    
    [self.navigationController setToolbarHidden:NO animated:YES];
    
    [self setupItems];
    
    if (self.searchDisplayController.active)
        [self.searchDisplayController.searchResultsTableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [self.accountManager removeObserver:self];

    if (store)
        [store removeObserver:self];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    self.editing = NO;
    
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
        [self.undoManager undo];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self positionSearchFieldForOrientation:toInterfaceOrientation];
    
    self.tableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, toInterfaceOrientation == UIInterfaceOrientationPortrait ? kTableFooterViewHeight : kTableFooterViewHeight / 2, 0.0);
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
        store = [DBDatastore openDefaultStoreForAccount:self.account error:nil];

    return store;
}

#pragma mark - Actions

- (NSInteger)activeItemCount
{
    return [[NSMutableArray arrayWithArray:[dataTable query:@{ @"active": @YES } error:nil]] count];
}

- (IBAction)add:(id)sender
{
    DBRecord *record = [dataTable insert:@{ @"active": @NO, @"created": [NSDate date], @"name": @"", @"details": @"" }];
    currentRecord = record;

    [self performSegueWithIdentifier:kSegueShowFormId sender:self];
}

- (void)disableActionButtons
{
    self.navigationController.navigationBar.topItem.leftBarButtonItem.enabled = NO;
    self.navigationController.navigationBar.topItem.rightBarButtonItem.enabled = NO;
    filterControl.enabled = NO;
}

- (void)enableActionButtons
{
    self.navigationController.navigationBar.topItem.leftBarButtonItem.enabled = YES;
    self.navigationController.navigationBar.topItem.rightBarButtonItem.enabled = YES;
    filterControl.enabled = YES;
}

-(void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    [searchResults removeAllObjects];

    if ([searchText isEqualToString:@""])
        return;
    
    for (NSArray *section in items)
    {
        for (DBRecord *item in section)
        {
            NSRange nameTextRange = [[item[@"name"] lowercaseString] rangeOfString:[searchText lowercaseString]];
            NSRange detailsTextRange = [[item[@"details"] lowercaseString] rangeOfString:[searchText lowercaseString]];
            
            if (nameTextRange.location != NSNotFound || detailsTextRange.location != NSNotFound)
                [searchResults addObject:item];
        }
    }
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
        UINavigationController *navigationController = segue.destinationViewController;
        FormViewController *destinationController = [[navigationController childViewControllers] objectAtIndex:0];
        destinationController.delegate = self;
        [destinationController setRecord:currentRecord];
    }
    else if ([segue.identifier isEqualToString:kSegueShowProductImage])
    {
        ItemViewController *destinationController = segue.destinationViewController;
        [destinationController setRecord:currentRecord];
    }
    
    currentRecord = nil;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];

    [self.navigationController.navigationBar.topItem.rightBarButtonItem setEnabled: ! editing];
    
    [self.tableView setEditing:editing animated:YES];
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
    [filterControl setSegmentedControlStyle:UISegmentedControlStyleBar];
    [filterControl setSelectedSegmentIndex:selectedFilterSegment];
    [filterControl addTarget:self action:@selector(toggleFilter:) forControlEvents:UIControlEventValueChanged];
    
    UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithCustomView:filterControl];
    UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    self.toolbarItems = @[spaceItem, barButton, spaceItem];
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
        item = (DBRecord *)[searchResults objectAtIndex:indexPath.row];
    else
        item = (DBRecord *)[[items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
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
        [self displayErrorAlert:error];
    
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
        int idx = [rawItems indexOfObject:record];
        
        [inserts addObject:[NSIndexPath indexPathForRow:idx inSection:0]];
    }
    
    items = (NSMutableArray *)[self partitionObjects:rawItems collationStringSelector:@selector(self)];

    if ( ! self.searchDisplayController.active)
        [self.tableView reloadData];
}

- (void)updateBadgeCount
{
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[self activeItemCount]];
}

- (void)updateFooterCount
{
    UILabel *footerView = (UILabel *)self.tableView.tableFooterView;
    NSString *suffix = rawItems.count == 1 ? NSLocalizedString(@"UITableViewFooterLabelItemSingular", nil) : NSLocalizedString(@"UITableViewFooterLabelItemPlural", nil);
    footerView.text = [NSString stringWithFormat:@"%i %@", rawItems.count, suffix];
}

#pragma mark - UISearchDisplayController Delegate Methods

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller
{
    [self animateViewInForOrientation:self.interfaceOrientation];
}

- (void)animateViewInForOrientation:(UIInterfaceOrientation)orientation
{
    UIApplication *app = [UIApplication sharedApplication];
    
    CGRect searchBarFrame = self.searchDisplayController.searchBar.frame;
    CGRect tableViewFrame = self.tableView.frame;
    
    searchBarYOrigin = searchBarFrame.origin.y;
    tableViewYOrigin = tableViewFrame.origin.y;
    
    CGFloat searchBarFrameY = floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1 ? 0.0 : (orientation == UIInterfaceOrientationPortrait) ? app.statusBarFrame.size.height : app.statusBarFrame.size.width;
    CGFloat tableViewFrameY = floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1 ? searchBarFrame.size.height : (orientation == UIInterfaceOrientationPortrait) ? searchBarYOrigin : searchBarYOrigin + 12.0;
    
    searchBarFrame.origin.y = searchBarFrameY;
    tableViewFrame.origin.y = tableViewFrameY;
    
    [UIView animateWithDuration:kSearchResultsAnimationDuration animations:^(void){
        self.searchDisplayController.searchBar.frame = searchBarFrame;
        self.tableView.frame = tableViewFrame;
    }];
}

- (void)animateViewOutForOrientation:(UIInterfaceOrientation)orientation
{
    CGRect searchBarFrame = self.searchDisplayController.searchBar.frame;
    CGRect tableViewFrame = self.tableView.frame;
    
    searchBarFrame.origin.y = searchBarYOrigin;
    tableViewFrame.origin.y = tableViewYOrigin;
    
    [UIView animateWithDuration:kSearchResultsAnimationDuration animations:^(void){
        self.searchDisplayController.searchBar.frame = searchBarFrame;
        self.tableView.frame = tableViewFrame;
    }];
}

- (void)positionSearchFieldForOrientation:(UIInterfaceOrientation)orientation
{
    CGRect searchBarFrame = self.searchDisplayController.searchBar.frame;
    CGRect tableViewFrame = self.tableView.frame;
    
    searchBarFrame.origin.y = orientation == UIInterfaceOrientationPortrait ? searchBarYOrigin : searchBarLandscapeY;
    CGFloat searchBarHeight = searchBarFrame.origin.y + searchBarFrame.size.height;
    tableViewFrame.origin.y = searchBarHeight;

    [UIView animateWithDuration:kSearchResultsAnimationDuration animations:^(void){
        self.searchDisplayController.searchBar.frame = searchBarFrame;
        self.tableView.frame = tableViewFrame;
    }];
}

- (void)searchDisplayControllerDidBeginSearch:(UISearchDisplayController *)controller
{
    [self disableActionButtons];
}

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterContentForSearchText:searchString scope:nil];
    
    return YES;
}

- (void)searchDisplayControllerWillEndSearch:(UISearchDisplayController *)controller
{
    [self animateViewOutForOrientation:self.interfaceOrientation];
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller
{
    [self enableActionButtons];
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

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    BOOL showSection = [[items objectAtIndex:section] count] != 0;
    
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
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kTableViewCellIdentifier];
    
    DBRecord *item = nil;
    
    if (tableView == self.searchDisplayController.searchResultsTableView)
        item = (DBRecord *)[searchResults objectAtIndex:indexPath.row];
    else
        item = (DBRecord *)[[items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    cell.textLabel.text = item[@"name"];
    cell.detailTextLabel.text = item[@"details"];
        
    UISwitch *switchControl = [[UISwitch alloc] initWithFrame:CGRectZero];
    [switchControl setOn:[item[@"active"] boolValue]];
    [switchControl setOnTintColor:[UIColor orangeColor]];
    [switchControl addTarget:self action:@selector(switchToggle:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = switchControl;

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return ! self.searchDisplayController.active;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        DBRecord *item = (DBRecord *)[[items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        [item deleteRecord];
        
        [self syncStore];
        [self syncItems];
    }
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
    
    [self performSegueWithIdentifier:tableView.isEditing ? kSegueShowFormId : kSegueShowProductImage sender:self];
}

#pragma mark - FormViewControllerDelegate

- (void)didFinishEditingItem:(DBRecord *)record
{
    [self syncStore];
    [self playAudioFile:kAudioEditingName];
}

- (void)didCancelEditingItem:(DBRecord *)record
{
    [record deleteRecord];
    [self syncStore];
}

@end
