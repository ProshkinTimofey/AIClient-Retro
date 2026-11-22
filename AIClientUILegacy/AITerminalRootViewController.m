//
//  AITerminalRootViewController.m
//  AIClient
//
//  Theme-aware root view controller with manual layout
//

#import "AITerminalRootViewController.h"
#import "AITerminalChatViewController.h"
#import "AITerminalSettingsViewController.h"
#import "AITerminalProviderSelectorViewController.h"
#import "AIConversationManager.h"
#import "AIAPIManager.h"
#import "AIProviderProtocol.h"
#import "AIKeychainManager.h"
#import "AITerminalConversationCell.h"
#import "AITerminalStatusBar.h"
#import "AITheme.h"

@interface AITerminalRootViewController () <AIConversationManagerDelegate>

@property (nonatomic, strong) AITerminalStatusBar *statusBar;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) id<AITheme> currentTheme;
@property (nonatomic, assign) BOOL needsLayout;

@end

@implementation AITerminalRootViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"AIClient";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Chats" image:nil tag:0];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _currentTheme = [[AIThemeManager sharedManager] currentTheme];
    _needsLayout = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(themeDidChange:)
                                                 name:@"AIThemeDidChangeNotification"
                                               object:nil];

    [self applyTheme];
    [self setupTableView];
    [self setupNavigationBar];
    [self setupStatusBar];
    [self setupDelegates];
    [self loadConversations];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadConversations];
    [self updateStatusBar];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (_needsLayout) {
        [self layoutSubviewsManually];
        _needsLayout = NO;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Theme

- (void)themeDidChange:(NSNotification *)note {
    _currentTheme = [[AIThemeManager sharedManager] currentTheme];
    [self applyTheme];
    [self.view setNeedsLayout];
}

- (void)applyTheme {
    id<AITheme> theme = _currentTheme;

    self.view.backgroundColor = theme.backgroundColor;
    self.tableView.backgroundColor = theme.backgroundColor;
    self.tableView.separatorColor = theme.separatorColor;
    self.tableView.separatorInset = UIEdgeInsetsZero;

    [theme styleNavigationBar:self.navigationController.navigationBar];

    // Style navigation bar buttons
    for (UIBarButtonItem *item in @[self.navigationItem.leftBarButtonItem, self.navigationItem.rightBarButtonItem]) {
        [theme styleBarButton:item withTheme:theme];
    }

    // Refresh control
    if (self.refreshControl) {
        self.refreshControl.tintColor = theme.primaryColor;
        self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"> loading..." attributes:@{NSForegroundColorAttributeName: theme.primaryColor, NSFontAttributeName: theme.fontCaption}];
    }

    [self updateStatusBar];
    [self.tableView reloadData];
}

#pragma mark - Manual Layout

- (void)layoutSubviewsManually {
    CGRect bounds = self.view.bounds;
    CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height;
    CGFloat statusBarFrame = UIApplication.sharedApplication.statusBarFrame.size.height;
    CGFloat topOffset = navBarHeight + statusBarFrame;
    CGFloat statusBarHeight = 22;

    self.tableView.frame = CGRectMake(0, topOffset, bounds.size.width, bounds.size.height - topOffset - statusBarHeight);
    self.statusBar.frame = CGRectMake(0, bounds.size.height - statusBarHeight, bounds.size.width, statusBarHeight);
}

- (void)setNeedsManualLayout {
    _needsLayout = YES;
    [self.view setNeedsLayout];
}

#pragma mark - Setup

- (void)setupTableView {
    [self.tableView registerClass:[AITerminalConversationCell class] forCellReuseIdentifier:@"ConversationCell"];
    self.tableView.rowHeight = 60;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // Refresh control with theme
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = _currentTheme.primaryColor;
    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"> loading..." attributes:@{NSForegroundColorAttributeName: _currentTheme.primaryColor, NSFontAttributeName: _currentTheme.fontCaption}];
    [self.refreshControl addTarget:self action:@selector(loadConversations) forControlEvents:UIControlEventValueChanged];
}

- (void)setupNavigationBar {
    // Left: Settings
    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithTitle:@"[Settings]" style:UIBarButtonItemStylePlain target:self action:@selector(settingsTapped)];
    [_currentTheme styleBarButton:settingsButton withTheme:_currentTheme];

    // Right: New Chat
    UIBarButtonItem *newChatButton = [[UIBarButtonItem alloc] initWithTitle:@"[New Chat]" style:UIBarButtonItemStylePlain target:self action:@selector(newChatTapped)];
    [_currentTheme styleBarButton:newChatButton withTheme:_currentTheme];

    self.navigationItem.leftBarButtonItem = settingsButton;
    self.navigationItem.rightBarButtonItem = newChatButton;

    // Title with terminal prompt style
    self.navigationItem.titleView = nil;
    self.navigationItem.prompt = @"> conversations";
}

- (void)setupStatusBar {
    self.statusBar = [[AITerminalStatusBar alloc] initWithFrame:CGRectZero];
    self.statusBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.statusBar];

    [self updateStatusBar];
}

- (void)setupDelegates {
    [[AIConversationManager sharedManager] setDelegate:self];
}

- (void)loadConversations {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        self.conversations = [[AIConversationManager sharedManager] allConversations];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
            [self.refreshControl endRefreshing];
            [self updateStatusBar];
        });
    });
}

- (void)updateStatusBar {
    AIAPIManager *apiManager = [AIAPIManager sharedManager];
    id<AIProviderProtocol> provider = apiManager.currentProvider;

    NSString *providerName = provider ? provider.providerName : @"No Provider";
    NSString *modelName = apiManager.currentModel ?: @"-";
    NSUInteger convCount = self.conversations.count;

    self.statusBar.providerLabel.text = [NSString stringWithFormat:@"> %@", providerName];
    self.statusBar.modelLabel.text = [NSString stringWithFormat:@"model: %@", modelName];
    self.statusBar.countLabel.text = [NSString stringWithFormat:@"chats: %lu", (unsigned long)convCount];

    // Apply theme to status bar
    [_currentTheme styleLabel:self.statusBar.providerLabel style:@"monospace"];
    [_currentTheme styleLabel:self.statusBar.modelLabel style:@"monospace"];
    [_currentTheme styleLabel:self.statusBar.countLabel style:@"caption"];
    self.statusBar.backgroundColor = _currentTheme.surfaceColor;
}

#pragma mark - Actions

- (void)newChatTapped {
    AIConversation *conversation = [[AIConversationManager sharedManager] createNewConversationWithTitle:@"New Chat"];
    [self openConversation:conversation];
}

- (void)settingsTapped {
    AITerminalSettingsViewController *settingsVC = [[AITerminalSettingsViewController alloc] init];
    [self.navigationController pushViewController:settingsVC animated:YES];
}

- (void)openConversation:(AIConversation *)conversation {
    AITerminalChatViewController *chatVC = [[AITerminalChatViewController alloc] initWithConversation:conversation];
    [self.navigationController pushViewController:chatVC animated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.conversations.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AITerminalConversationCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ConversationCell" forIndexPath:indexPath];
    AIConversation *conversation = self.conversations[indexPath.row];
    [cell configureWithConversation:conversation index:indexPath.row theme:_currentTheme];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    AIConversation *conversation = self.conversations[indexPath.row];
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
        AIConversation *conversation = self.conversations[indexPath.row];

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"> delete conversation"
                                                        message:@"Are you sure?"
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"Delete", nil];
        [_currentTheme styleAlertView:alert];
        alert.tag = indexPath.row + 1000;
        [alert show];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1 && alertView.tag >= 1000) {
        NSUInteger index = alertView.tag - 1000;
        if (index < self.conversations.count) {
            AIConversation *conversation = self.conversations[index];
            [[AIConversationManager sharedManager] deleteConversation:conversation completion:nil];
        }
    }
}

#pragma mark - AIConversationManagerDelegate

- (void)conversationManager:(id)manager didCreateConversation:(NSString *)conversationID {
    [self loadConversations];
}

- (void)conversationManager:(id)manager didUpdateConversation:(NSString *)conversationID) {
    [self loadConversations];
}

- (void)conversationManager:(id)manager didDeleteConversation:(NSString *)conversationID) {
    [self loadConversations];
}

- (void)conversationManager:(id)manager didAddMessage:(AIMessage *)message toConversation:(NSString *)conversationID) {
    [self loadConversations];
}

@end