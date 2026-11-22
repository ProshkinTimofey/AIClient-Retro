//
//  AIRootViewController.m
//  AIClient
//

#import "AIRootViewController.h"
#import "AIChatViewController.h"
#import "AISettingsViewController.h"
#import "AIConversationManager.h"
#import "AIConversation.h"
#import "AIAPIManager.h"
#import "AIProviderProtocol.h"

@interface AIRootViewController ()

@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIBarButtonItem *newChatButton;
@property (nonatomic, strong) UIBarButtonItem *settingsButton;

@end

@implementation AIRootViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInscribedGrouped];
    if (self) {
        self.title = @"AIClient";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Chats" image:[UIImage systemImageNamed:@"bubble.left.and.bubble.right"] tag:0];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupTableView];
    [self setupNavigationBar];
    [self setupSearchController];
    [self setupDelegates];
    [self loadConversations];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];

    // Check if provider is configured
    if (![[AIAPIManager sharedManager] currentProvider]) {
        [self showProviderSetupAlert];
    }
}

- (void)setupTableView {
    self.tableView.registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ConversationCell"];
    self.tableView.rowHeight = 80;
    self.tableView.estimatedRowHeight = 80;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 72, 0, 0);

    // Refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(loadConversations) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;
}

- (void)setupNavigationBar {
    // New chat button
    self.newChatButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(newChatTapped)];
    self.newChatButton.accessibilityIdentifier = @"newChatButton";

    // Settings button
    self.settingsButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape"] style:UIBarButtonItemStylePlain target:self action:@selector(settingsTapped)];
    self.settingsButton.accessibilityIdentifier = @"settingsButton";

    self.navigationItem.rightBarButtonItems = @[self.settingsButton, self.newChatButton];
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
}

- (void)setupSearchController {
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"Search conversations";
    self.searchController.searchBar.delegate = self;
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
}

- (void)setupDelegates {
    [[AIConversationManager sharedManager] setDelegate:self];
}

- (void)loadConversations {
    [self.refreshControl beginRefreshing];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // Conversations are loaded in AIConversationManager init
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
            [self.refreshControl endRefreshing];
        });
    });
}

- (void)newChatTapped {
    AIConversation *conversation = [[AIConversationManager sharedManager] createNewConversationWithTitle:@"New Chat"];
    [self openConversation:conversation];
}

- (void)settingsTapped {
    AISettingsViewController *settingsVC = [[AISettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)showProviderSetupAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"No AI Provider Configured"
                                                                   message:@"Please add an API key in Settings to start chatting."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Open Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self settingsTapped];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openConversation:(AIConversation *)conversation {
    AIChatViewController *chatVC = [[AIChatViewController alloc] initWithConversation:conversation];
    [self.navigationController pushViewController:chatVC animated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.isSearching) {
        return self.filteredConversations.count;
    }
    return [[AIConversationManager sharedManager] allConversations].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ConversationCell" forIndexPath:indexPath];

    AIConversation *conversation = self.isSearching ? self.filteredConversations[indexPath.row] : [[AIConversationManager sharedManager] allConversations][indexPath.row];

    // Configure cell
    var content = cell.defaultContentConfiguration;
    content.text = conversation.title;
    content.secondaryText = conversation.lastMessage?.content ?: @"No messages yet";
    content.secondaryTextProperties.color = [UIColor secondaryLabel];
    content.secondaryTextProperties.numberOfLines = 2;
    content.image = [UIImage systemImageNamed:@"bubble.left.and.bubble.right"];
    content.imageProperties.tintColor = [UIColor systemBlueColor];
    content.imageProperties.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightMedium];
    content.textProperties.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    content.prefersSideBySideImageAndSecondaryText = NO;
    cell.contentConfiguration = content;

    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.backgroundConfiguration = [UIBackgroundConfiguration clearBackgroundConfiguration];

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    AIConversation *conversation = self.isSearching ? self.filteredConversations[indexPath.row] : [[AIConversationManager sharedManager] allConversations][indexPath.row];
    [self openConversation:conversation];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        AIConversation *conversation = self.isSearching ? self.filteredConversations[indexPath.row] : [[AIConversationManager sharedManager] allConversations][indexPath.row];

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete Conversation"
                                                                       message:@"Are you sure you want to delete this conversation?"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [[AIConversationManager sharedManager] deleteConversation:conversation completion:nil];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (NSArray<UIContextualAction *> *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    AIConversation *conversation = self.isSearching ? self.filteredConversations[indexPath.row] : [[AIConversationManager sharedManager] allConversations][indexPath.row];

    UIContextualAction *renameAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Rename" handler:^(UIContextualAction *action, UIView *view, void (^completion)(BOOL)) {
        [self renameConversation:conversation];
        completion(YES);
    }];
    renameAction.backgroundColor = [UIColor systemOrangeColor];
    renameAction.image = [UIImage systemImageNamed:@"pencil"];

    UIContextualAction *duplicateAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Duplicate" handler:^(UIContextualAction *action, UIView *view, void (^completion)(BOOL)) {
        [self duplicateConversation:conversation];
        completion(YES);
    }];
    duplicateAction.backgroundColor = [UIColor systemBlueColor];
    duplicateAction.image = [UIImage systemImageNamed:@"doc.on.doc"];

    return @[renameAction, duplicateAction];
}

- (void)renameConversation:(AIConversation *)conversation {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Rename Conversation"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = conversation.title;
        textField.placeholder = @"Conversation title";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *newTitle = alert.textFields[0].text;
        if (newTitle && newTitle.length > 0) {
            conversation.title = newTitle;
            conversation.updatedAt = [NSDate date];
            [[AIConversationManager sharedManager] saveAllConversations];
            [self.tableView reloadData];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)duplicateConversation:(AIConversation *)conversation {
    AIConversation *newConv = [[AIConversationManager sharedManager] createNewConversationWithTitle:[conversation.title stringByAppendingString:@" (Copy)"]];
    newConv.systemPrompt = conversation.systemPrompt;
    newConv.model = conversation.model;
    newConv.temperature = conversation.temperature;
    newConv.maxTokens = conversation.maxTokens;
    newConv.messages = [conversation.messages mutableCopy];
    [[AIConversationManager sharedManager] saveAllConversations];
    [self.tableView reloadData];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchText = searchController.searchBar.text;
    self.isSearching = searchText.length > 0;

    if (self.isSearching) {
        self.filteredConversations = [[AIConversationManager sharedManager] conversationsContainingText:searchText];
    }
    [self.tableView reloadData];
}

#pragma mark - AIConversationManagerDelegate

- (void)conversationManager:(id)manager didCreateConversation:(NSString *)conversationID {
    [self.tableView reloadData];
}

- (void)conversationManager:(id)manager didUpdateConversation:(NSString *)conversationID {
    [self.tableView reloadData];
}

- (void)conversationManager:(id)manager didDeleteConversation:(NSString *)conversationID {
    [self.tableView reloadData];
}

- (void)conversationManager:(id)manager didAddMessage:(AIMessage *)message toConversation:(NSString *)conversationID {
    [self.tableView reloadData];
}

- (void)conversationManager:(id)manager didUpdateMessage:(AIMessage *)message inConversation:(NSString *)conversationID {
    [self.tableView reloadData];
}

@end