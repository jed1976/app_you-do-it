//
//  ListViewController.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import "ListViewController.h"

NSInteger kInitialSelectedFilterSegment = 0;
NSString *kSegueShowFormId = @"editItemSegue";
NSString *kSegueShowProductImage = @"productImageSegue";
NSString *kTableName = @"ShoppingList";
NSString *kAudioEditingName = @"You Do It";
NSString *kAudioRemovingName = @"You Promised";
NSString *kAudioActivatingName = @"Oh Yeah";
CGFloat kTableFooterViewHeight = 44.0;
NSString *kTableViewCellIdentifier = @"Cell";

@interface ListViewController ()
{
    AVAudioPlayer *audioPlayer;
}

@property (nonatomic, readonly) DBAccount *account;
@property (nonatomic, readonly) DBAccountManager *accountManager;
@property (nonatomic) NSIndexPath *currentEditIndexPath;
@property (nonatomic) DBRecord *currentRecord;
@property (nonatomic) UISegmentedControl *filterControl;
@property (nonatomic) NSMutableArray *items;
@property (nonatomic) ProductImageViewController *productImageViewController;
@property (nonatomic) NSMutableArray *rawItems;
@property (nonatomic) IBOutlet UISearchBar *searchBar;
@property (nonatomic) NSMutableArray *searchResults;
@property (nonatomic) NSInteger selectedFilterSegment;
@property (nonatomic) DBDatastore *store;
@property (nonatomic) DBTable *table;
@property (nonatomic) NSUndoManager *undoManager;

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
    
    [self setupFilesystem];
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
    
    [self.navigationController setToolbarHidden:NO animated:YES];
    
    [self setupItems];
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

    if (self.store)
        [self.store removeObserver:self];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    self.editing = NO;
    
    self.currentRecord = nil;
    self.items = nil;
    self.rawItems = nil;
    self.searchResults = nil;
    
    [self resignFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    self.currentRecord = nil;
    self.items = nil;
    self.rawItems = nil;
    self.searchResults = nil;
    self.store = nil;
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion == UIEventSubtypeMotionShake)
        [self.undoManager undo];
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
    if ( ! _store)
        _store = [DBDatastore openDefaultStoreForAccount:self.account error:nil];

    return _store;
}

#pragma mark - Actions

- (NSInteger)activeItemCount
{
    NSMutableArray *activeItems = [NSMutableArray arrayWithArray:[self.table query:@{ @"active": @YES } error:nil]];
    
    return activeItems.count;
}

- (IBAction)add:(id)sender
{
    DBRecord *record = [self.table insert:@{
        @"active": @NO,
        @"created": [NSDate date],
        @"name": @"",
        @"details": @""
    }];
    
    self.currentRecord = record;

    [self performSegueWithIdentifier:kSegueShowFormId sender:self];
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

-(void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    [self.searchResults removeAllObjects];

    if ([searchText isEqualToString:@""])
        return;
    
    for (NSArray *section in self.items)
    {
        for (DBRecord *item in section)
        {
            NSRange nameTextRange = [[item[@"name"] lowercaseString] rangeOfString:[searchText lowercaseString]];
            NSRange detailsTextRange = [[item[@"details"] lowercaseString] rangeOfString:[searchText lowercaseString]];
            
            if (nameTextRange.location != NSNotFound || detailsTextRange.location != NSNotFound)
                [self.searchResults addObject:item];
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
        [destinationController setRecord:self.currentRecord];
    }
    else if ([segue.identifier isEqualToString:kSegueShowProductImage])
    {
        ProductImageViewController *destinationController = segue.destinationViewController;
        [destinationController setRecord:self.currentRecord];
    }
    
    self.currentRecord = nil;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];

    [self.navigationController.navigationBar.topItem.rightBarButtonItem setEnabled: ! [self.tableView isEditing]];
}

- (void)setRecord:(DBRecord *)record activeState:(NSNumber *)activeState
{
    record[@"active"] = activeState;
    [self syncStore];
    [self setupItems];
}

- (void)setupFilesystem
{
    DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];
    DBFilesystem *filesystem = [[DBFilesystem alloc] initWithAccount:account];
    [DBFilesystem setSharedFilesystem:filesystem];
}

- (void)setupFilterControl
{
    self.selectedFilterSegment = kInitialSelectedFilterSegment;
    
    self.filterControl = [[UISegmentedControl alloc] initWithItems:@[NSLocalizedString(@"UISegmentedControlItem1", nil), NSLocalizedString(@"UISegmentedControlItem2", nil)]];
    [self.filterControl setSegmentedControlStyle:UISegmentedControlStyleBar];
    [self.filterControl setSelectedSegmentIndex:self.selectedFilterSegment];
    [self.filterControl addTarget:self action:@selector(toggleFilter:) forControlEvents:UIControlEventValueChanged];
    
    UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithCustomView:self.filterControl];
    UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    self.toolbarItems = @[spaceItem, barButton, spaceItem];
}

- (void)setupItems
{
    DBError *error;
    
    self.rawItems = [NSMutableArray array];
    self.searchResults = [NSMutableArray array];
    
    if (self.account)
    {
        __weak ListViewController *slf = self;
        self.table = [self.store getTable:kTableName];
        
        [self.store addObserver:self block:^() {
            if (slf.store.status & (DBDatastoreIncoming | DBDatastoreOutgoing)) {
                [slf syncItems];
            }
        }];
        
        _rawItems = [NSMutableArray arrayWithArray:[self.table query:self.selectedFilterSegment == 0 ? nil : @{ @"active": @YES } error:&error]];
        
        if (error != nil)
            [self displayErrorAlert:error];
    }
    else
    {
        [[DBAccountManager sharedManager] linkFromController:self];
    }
    
    [self syncItems];
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
    self.currentEditIndexPath = indexPath;
    
    DBRecord *item = nil;
    
    if (self.searchDisplayController.active)
        item = (DBRecord *)[self.searchResults objectAtIndex:indexPath.row];
    else
        item = (DBRecord *)[[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
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
    self.selectedFilterSegment = [sender selectedSegmentIndex];

    [self setupItems];
}

- (void)update:(NSDictionary *)changedDict
{
    NSMutableArray *deleted = [NSMutableArray array];
    
    for (NSInteger i = [self.rawItems count] - 1; i >= 0; i--)
    {
        DBRecord *item = self.rawItems[i];
        
        if (item.deleted)
        {
            [deleted addObject:[NSIndexPath indexPathForRow:i inSection:0]];
            [self.rawItems removeObjectAtIndex:i];
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
            NSUInteger idx = [self.rawItems indexOfObject:record];
            
            if (idx != NSNotFound)
            {
                [updates addObject:[NSIndexPath indexPathForRow:idx inSection:0]];
                [changed removeObjectAtIndex:i];
            }
        }
    }
    
    [self.rawItems addObjectsFromArray:changed];
    
    NSMutableArray *inserts = [NSMutableArray array];
    
    for (DBRecord *record in changed)
    {
        int idx = [self.rawItems indexOfObject:record];
        
        [inserts addObject:[NSIndexPath indexPathForRow:idx inSection:0]];
    }
    
    self.items = (NSMutableArray *)[self partitionObjects:self.rawItems collationStringSelector:@selector(self)];

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
    NSString *suffix = self.rawItems.count == 1 ? NSLocalizedString(@"UITableViewFooterLabelItemSingular", nil) : NSLocalizedString(@"UITableViewFooterLabelItemPlural", nil);
    footerView.text = [NSString stringWithFormat:@"%i %@", self.rawItems.count, suffix];
}

#pragma mark - UISearchDisplayController Delegate Methods

- (void)searchDisplayControllerDidBeginSearch:(UISearchDisplayController *)controller
{
    self.editing = NO;
    [self disableActionButtons];
}

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterContentForSearchText:searchString
                               scope:[[self.searchDisplayController.searchBar scopeButtonTitles]
                                      objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    
    return YES;
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
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kTableViewCellIdentifier];
    
    DBRecord *item = nil;
    
    if (tableView == self.searchDisplayController.searchResultsTableView)
        item = (DBRecord *)[self.searchResults objectAtIndex:indexPath.row];
    else
        item = (DBRecord *)[[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
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
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        DBRecord *item = (DBRecord *)[[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
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
        self.currentRecord = [self.searchResults objectAtIndex:indexPath.row];
        self.searchDisplayController.active = NO;
    }
    else
    {
        self.currentRecord = [[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
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
