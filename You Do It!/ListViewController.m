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

@property (nonatomic, readonly) DBAccountManager *accountManager;
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

@end

@implementation ListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];
    DBFilesystem *filesystem = [[DBFilesystem alloc] initWithAccount:account];
    [DBFilesystem setSharedFilesystem:filesystem];
    
    [self playAudioFile:@"You Do It"];

    self.rawItems = [NSMutableArray array];
    self.searchResults = [NSMutableArray array];
    
    self.navigationItem.leftBarButtonItem = [self editButtonItem];
    
    [self addFilterControl];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    __weak ListViewController *slf = self;

    [self.accountManager addObserver:self block:^(DBAccount *account) {
        [slf setupItems];
    }];
    
    [self setupItems];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.accountManager removeObserver:self];

    if (_store)
        [_store removeObserver:self];
}

- (void)viewDidDisappear:(BOOL)animated
{
    self.editing = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    self.items = nil;
    self.rawItems = nil;
    self.searchResults = nil;
    self.store = nil;
}

#pragma mark - UIAlert actions

- (void)displayErrorAlert:(DBError *)error
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Error %i", error.code]
                                                    message:error.userInfo.description
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

- (IBAction)add:(id)sender
{
    [self disableActionButtons];
    
    DBRecord *record = [self.table insert:@{ @"active": @NO, @"created": [NSDate date], @"name": @"", @"details": @"", @"photo": @"" }];
    
    self.currentRecord = record;

    [self performSegueWithIdentifier:kSegueShowFormId sender:self];
}

- (void)addFilterControl
{
    self.selectedFilterSegment = 0;
    
    self.filterControl = [[UISegmentedControl alloc] initWithItems:@[@"All", @"Active"]];
    [self.filterControl setSegmentedControlStyle:UISegmentedControlStyleBar];
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

-(void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    [self.searchResults removeAllObjects];

    if ([searchText isEqualToString:@""])
        return;
    
    for (NSArray *section in self.items)
    {
        for (DBRecord *item in section)
        {
            NSRange textRange = [[item[@"name"] lowercaseString] rangeOfString:[searchText lowercaseString]];
            
            if (textRange.location != NSNotFound)
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
        [section sortedArrayUsingComparator:^(DBRecord *obj1, DBRecord *obj2) {
            return [obj1[@"name"] compare:obj2[@"name"]];
        }];
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
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];

    [self.navigationController.navigationBar.topItem.rightBarButtonItem setEnabled: ! [self.tableView isEditing]];
}

- (void)setupItems
{
    DBError *error;
    
    if (self.account)
    {
        __weak ListViewController *slf = self;
        self.table = [self.store getTable:kTableName];
        
        [self.store addObserver:self block:^() {
            if (slf.store.status & (DBDatastoreIncoming | DBDatastoreOutgoing)) {
                [slf syncItems];
            }
        }];
        
        if (self.selectedFilterSegment == 0)
            _rawItems = [NSMutableArray arrayWithArray:[self.table query:nil error:&error]];
        else
            _rawItems = [NSMutableArray arrayWithArray:[self.table query:@{ @"active": @YES } error:&error]];
        
        if (error != nil)
            [self displayErrorAlert:error];
    }
    else
    {
        _store = nil;
        _items = nil;
        self.rawItems = nil;
        
        [[DBAccountManager sharedManager] linkFromController:self];
    }
    
    [self syncItems];
}

- (IBAction)switchToggle:(id)sender
{
    UISwitch *switchControl = (UISwitch *)sender;
    UITableView *tableView = self.searchDisplayController.active ? self.searchDisplayController.searchResultsTableView : self.tableView;
    CGRect buttonFrame = [switchControl convertRect:switchControl.bounds toView:tableView];
    NSIndexPath *indexPath = [tableView indexPathForRowAtPoint:buttonFrame.origin];
    self.currentEditIndexPath = indexPath;
    
    DBRecord *item = nil;
    DBError *error;
    
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
        
        if ( ! self.searchDisplayController.active && self.selectedFilterSegment == 1)
        {
            [[self.items objectAtIndex:indexPath.section] removeObjectAtIndex:indexPath.row];
            [self.tableView deleteRowsAtIndexPaths:@[self.currentEditIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
}

- (void)syncItems
{
    if (self.account)
    {
        DBError *error;
        NSDictionary *changed = [self.store sync:&error];
        
        if (error != nil)
            [self displayErrorAlert:error];
        else
            [self update:changed];
    }
}

- (void)toggleFilter:(id)sender
{
    self.selectedFilterSegment = [sender selectedSegmentIndex];

    [self setupItems];
}

- (void)update:(NSDictionary *)changedDict
{
    [self disableActionButtons];
    
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
    
    NSMutableArray *changed = [NSMutableArray arrayWithArray:[changedDict[@"ShoppingList"] allObjects]];
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
    
    [self enableActionButtons];
}

#pragma mark - UISearchDisplayController Delegate Methods

- (void)searchDisplayControllerDidBeginSearch:(UISearchDisplayController *)controller

{
    self.editing = NO;
}

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterContentForSearchText:searchString
                               scope:[[self.searchDisplayController.searchBar scopeButtonTitles]
                                      objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    
    return YES;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
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
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    DBRecord *item = nil;
    
    if (tableView == self.searchDisplayController.searchResultsTableView)
        item = (DBRecord *)[self.searchResults objectAtIndex:indexPath.row];
    else
        item = (DBRecord *)[[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    [cell textLabel].text = [item objectForKey:@"name"];
    
    [cell detailTextLabel].text = [item objectForKey:@"details"];
        
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
        DBError *error;
        DBRecord *item = (DBRecord *)[[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        
        if ( ! [item[@"photo"] isEqualToString:@""])
        {
            DBPath *path = [[DBPath root] initWithString:item[@"photo"]];
            [[DBFilesystem sharedFilesystem] deletePath:path error:&error];
            
            if (error != nil)
                [self displayErrorAlert:error];
            else
                item[@"photo"] = @"";
        }
        
        [item deleteRecord];
        [self.store sync:&error];
        
        if (error != nil)
            [self displayErrorAlert:error];
        else
            [self syncItems];
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

    [self performSegueWithIdentifier:tableView.isEditing ? kSegueShowFormId : kSegueShowProductImage sender:self];
}

#pragma mark - FormViewControllerDelegate

- (void)didFinishEditingItem:(DBRecord *)record
{
    DBError *error;
    
    [self.store sync:&error];
    
    if (error != nil)
        [self displayErrorAlert:error];
    else
        [self playAudioFile:@"You Do It"];
}

- (void)didCancelEditingItem:(DBRecord *)record
{
    DBError *error;

    [record deleteRecord];
    [self.store sync:&error];
    
    if (error != nil)
        [self displayErrorAlert:error];
}

@end
