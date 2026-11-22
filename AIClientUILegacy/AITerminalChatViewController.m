//
//  AITerminalChatViewController.m
//  AIClient
//
//  iOS 6 compatible chat view with theme support and manual layout (no Auto Layout)
//

#import "AITerminalChatViewController.h"
#import "AIMessage.h"
#import "AIAttachment.h"
#import "AIAPIManager.h"
#import "AIConversationManager.h"
#import "AITerminalMessageView.h"
#import "AITerminalInputView.h"
#import "AITerminalAttachmentPickerViewController.h"
#import "AITerminalProviderSelectorViewController.h"
#import "AITerminalImageGenViewController.h"
#import "AITerminalLoadingIndicator.h"
#import "AITerminalStatusBar.h"
#import "AITheme.h"

@interface AITerminalChatViewController ()

@property (nonatomic, strong) AIConversation *conversation;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) AITerminalInputView *inputView;
@property (nonatomic, strong) AITerminalStatusBar *statusBar;
@property (nonatomic, strong) AITerminalLoadingIndicator *loadingIndicator;
@property (nonatomic, strong) UIBarButtonItem *modelButton;
@property (nonatomic, strong) UIBarButtonItem *attachButton;
@property (nonatomic, strong) UIBarButtonItem *imageGenButton;
@property (nonatomic, strong) UIBarButtonItem *moreButton;
@property (nonatomic, assign) BOOL isKeyboardVisible;
@property (nonatomic, assign) CGFloat keyboardHeight;
@property (nonatomic, assign) CGFloat inputViewHeight;
@property (nonatomic, assign) CGFloat statusBarHeight;
@property (nonatomic, strong) id<AITheme> currentTheme;
@property (nonatomic, assign) BOOL needsLayout;

@end

@implementation AITerminalChatViewController

- (instancetype)initWithConversation:(AIConversation *)conversation {
    self = [super init];
    if (self) {
        _conversation = conversation;
        self.title = conversation.title;
        self.hidesBottomBarWhenPushed = YES;
        _inputViewHeight = 44;
        _statusBarHeight = 20;
        _needsLayout = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _currentTheme = [[AIThemeManager sharedManager] currentTheme];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(themeDidChange:)
                                                 name:@"AIThemeDidChangeNotification"
                                               object:nil];

    [self applyTheme];
    [self setupTableView];
    [self setupInputView];
    [self setupNavigationBar];
    [self setupStatusBar];
    [self setupLoadingIndicator];
    [self setupKeyboardObservers];
    [self setupDelegates];
    [self loadMessages];

    [[AIAPIManager sharedManager] setDelegate:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES animated:animated];
    _needsLayout = YES;
    [self.view setNeedsLayout];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[AIAPIManager sharedManager] setDelegate:nil];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (_needsLayout) {
        [self layoutSubviewsManually];
        _needsLayout = NO;
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Ensure tableView content inset accounts for input view and status bar
    CGFloat bottomInset = _inputViewHeight + _statusBarHeight;
    if (self.isKeyboardVisible) {
        bottomInset += self.keyboardHeight;
    }
    self.tableView.contentInset = UIEdgeInsetsMake(12, 0, bottomInset, 0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
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

    [theme styleNavigationBar:self.navigationController.navigationBar];

    self.tableView.backgroundColor = theme.backgroundColor;
    self.tableView.separatorColor = theme.separatorColor;

    if (self.statusBar) [self.statusBar applyTheme:theme];
    if (self.inputView) [self.inputView applyTheme:theme];
    if (self.loadingIndicator) [self.loadingIndicator applyTheme:theme];

    // Style navigation bar buttons
    for (UIBarButtonItem *item in @[self.modelButton, self.attachButton, self.imageGenButton, self.moreButton]) {
        [theme styleBarButton:item withTheme:theme];
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

    // Table view: fills space between nav bar and status bar + input view
    CGFloat inputY = bounds.size.height - _inputViewHeight - _statusBarHeight;
    if (self.isKeyboardVisible) {
        inputY -= self.keyboardHeight;
    }
    CGFloat statusBarY = inputY - _statusBarHeight;

    self.tableView.frame = CGRectMake(0, topOffset, bounds.size.width, statusBarY - topOffset);
    self.statusBar.frame = CGRectMake(0, statusBarY, bounds.size.width, _statusBarHeight);
    self.inputView.frame = CGRectMake(0, inputY, bounds.size.width, _inputViewHeight);

    // Loading indicator centered in table view
    self.loadingIndicator.center = CGPointMake(CGRectGetMidX(self.tableView.bounds), CGRectGetMidY(self.tableView.bounds));
}

- (void)setNeedsManualLayout {
    _needsLayout = YES;
    [self.view setNeedsLayout];
}

#pragma mark - Setup

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.showsVerticalScrollIndicator = YES;
    self.tableView.showsHorizontalScrollIndicator = NO;
    [self.tableView registerClass:[AITerminalMessageView class] forCellReuseIdentifier:@"UserMessage"];
    [self.tableView registerClass:[AITerminalMessageView class] forCellReuseIdentifier:@"AssistantMessage"];
    [self.view addSubview:self.tableView];

    // Row height caching
    self.tableView.estimatedRowHeight = 60;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
}

- (void)setupInputView {
    self.inputView = [[AITerminalInputView alloc] initWithFrame:CGRectZero];
    self.inputView.delegate = self;
    self.inputView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.inputView];

    // Listen for input view height changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inputViewHeightDidChange:)
                                                 name:@"AITerminalInputViewHeightDidChangeNotification"
                                               object:self.inputView];
}

- (void)inputViewHeightDidChange:(NSNotification *)note {
    NSNumber *height = note.userInfo[@"height"];
    if (height) {
        _inputViewHeight = [height floatValue];
        [self setNeedsManualLayout];
    }
}

- (void)setupNavigationBar {
    id<AITheme> theme = _currentTheme;

    self.modelButton = [[UIBarButtonItem alloc] initWithTitle:[NSString stringWithFormat:@"[ %@ ]", [[AIAPIManager sharedManager] currentModel] ?: @"model"]
                                                        style:UIBarButtonItemStylePlain
                                                       target:self
                                                       action:@selector(modelTapped)];
    [self styleBarButton:self.modelButton withTheme:theme];

    self.attachButton = [[UIBarButtonItem alloc] initWithTitle:@"[Attach]"
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(attachTapped)];
    [self styleBarButton:self.attachButton withTheme:theme];

    self.imageGenButton = [[UIBarButtonItem alloc] initWithTitle:@"[Generate]"
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(imageGenTapped)];
    [self styleBarButton:self.imageGenButton withTheme:theme];

    self.moreButton = [[UIBarButtonItem alloc] initWithTitle:@"[More]"
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(moreTapped)];
    [self styleBarButton:self.moreButton withTheme:theme];

    self.navigationItem.rightBarButtonItems = @[self.moreButton, self.imageGenButton, self.attachButton, self.modelButton];
}

- (void)styleBarButton:(UIBarButtonItem *)button withTheme:(id<AITheme>)theme {
    button.tintColor = theme.primaryColor;
    [button setTitleTextAttributes:@{
        NSFontAttributeName: theme.fontMonospaceSmall,
        NSForegroundColorAttributeName: theme.primaryColor
    } forState:UIControlStateNormal];
}

- (void)setupStatusBar {
    self.statusBar = [[AITerminalStatusBar alloc] initWithFrame:CGRectZero];
    self.statusBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.statusBar];

    [self updateStatusBar];
}

- (void)updateStatusBar {
    AIAPIManager *apiManager = [AIAPIManager sharedManager];
    id<AIProviderProtocol> provider = apiManager.currentProvider;

    self.statusBar.providerLabel.text = [NSString stringWithFormat:@"[ %@ ]", provider ? provider.providerName : @"No Provider"];
    self.statusBar.modelLabel.text = [NSString stringWithFormat:@"Model: %@", apiManager.currentModel ?: @"-"];
    self.statusBar.countLabel.text = [NSString stringWithFormat:@"Tokens: ~%lu", (unsigned long)[apiManager estimateTokenCountForConversation:self.conversation.messages]];

    // Apply theme to status bar
    [_currentTheme styleLabel:self.statusBar.providerLabel style:@"monospace"];
    [_currentTheme styleLabel:self.statusBar.modelLabel style:@"monospace"];
    [_currentTheme styleLabel:self.statusBar.countLabel style:@"caption"];
    self.statusBar.backgroundColor = _currentTheme.surfaceColor;
}

- (void)setupLoadingIndicator {
    self.loadingIndicator = [[AITerminalLoadingIndicator alloc] initWithFrame:CGRectZero];
    self.loadingIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.loadingIndicator.hidden = YES;
    [self.view addSubview:self.loadingIndicator];
}

- (void)setupDelegates {
    [[AIConversationManager sharedManager] setDelegate:self];
}

- (void)setupKeyboardObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)loadMessages {
    [self.tableView reloadData];
    [self scrollToBottomAnimated:NO];
}

#pragma mark - Actions

- (void)modelTapped {
    AITerminalProviderSelectorViewController *selector = [[AITerminalProviderSelectorViewController alloc] init];
    selector.delegate = self;
    [self.navigationController pushViewController:selector animated:YES];
}

- (void)attachTapped {
    AITerminalAttachmentPickerViewController *picker = [[AITerminalAttachmentPickerViewController alloc] init];
    picker.delegate = self;
    [self.navigationController pushViewController:picker animated:YES];
}

- (void)imageGenTapped {
    AITerminalImageGenViewController *genVC = [[AITerminalImageGenViewController alloc] init];
    genVC.delegate = self;
    [self.navigationController pushViewController:genVC animated:YES];
}

- (void)moreTapped {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                           destructiveButtonTitle:@"Clear Conversation"
                                                otherButtonTitles:@"Export", @"Regenerate Last", @"Theme", nil];
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) { // Clear
        [self confirmClear];
    } else if (buttonIndex == 1) { // Export
        [self exportConversation];
    } else if (buttonIndex == 2) { // Regenerate
        [self regenerateLast];
    } else if (buttonIndex == 3) { // Theme
        [self showThemeSelector];
    }
}

- (void)showThemeSelector {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Select Theme"
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                           destructiveButtonTitle:nil
                                                otherButtonTitles:@"Skeuomorphic (iOS 6)", @"Minimalist (iOS 13+)", @"Claude Code (Terminal)", nil];
    sheet.tag = 1000;
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 1000) {
        if (buttonIndex == 0) [[AIThemeManager sharedManager] setThemeType:AIThemeTypeSkeuomorphic animated:YES];
        else if (buttonIndex == 1) [[AIThemeManager sharedManager] setThemeType:AIThemeTypeMinimalist animated:YES];
        else if (buttonIndex == 2) [[AIThemeManager sharedManager] setThemeType:AIThemeTypeClaudeCode animated:YES];
        return;
    }

    if (buttonIndex == 0) { // Clear
        [self confirmClear];
    } else if (buttonIndex == 1) { // Export
        [self exportConversation];
    } else if (buttonIndex == 2) { // Regenerate
        [self regenerateLast];
    }
}

- (void)confirmClear {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Clear Conversation"
                                                    message:@"Remove all messages?"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Clear", nil];
    alert.tag = 999;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 999 && buttonIndex == 1) {
        self.conversation.messages = @[];
        [[AIConversationManager sharedManager] saveAllConversations];
        [self.tableView reloadData];
    }
}

- (void)exportConversation {
    NSData *data = [[AIConversationManager sharedManager] exportConversation:self.conversation error:nil];
    if (data) {
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[data] applicationActivities:nil];
        [self presentViewController:activityVC animated:YES completion:nil];
    }
}

- (void)regenerateLast {
    NSUInteger count = self.conversation.messages.count;
    if (count >= 2) {
        AIMessage *assistantMsg = self.conversation.messages[count - 1];
        AIMessage *userMsg = self.conversation.messages[count - 2];
        if (assistantMsg.role == AIMessageRoleAssistant && userMsg.role == AIMessageRoleUser) {
            [self.conversation.messages removeObject:assistantMsg];
            [[AIAPIManager sharedManager] sendMessage:userMsg conversationID:self.conversation.conversationID completion:nil];
        }
    }
}

#pragma mark - Keyboard

- (void)keyboardWillShow:(NSNotification *)note {
    self.isKeyboardVisible = YES;
    NSDictionary *info = note.userInfo;
    CGRect frame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    frame = [self.view convertRect:frame fromView:nil];
    self.keyboardHeight = frame.size.height;

    [self setNeedsManualLayout];
    [UIView animateWithDuration:0.25 animations:^{ [self.view layoutIfNeeded]; }];
    [self scrollToBottomAnimated:YES];
}

- (void)keyboardWillHide:(NSNotification *)note {
    self.isKeyboardVisible = NO;
    self.keyboardHeight = 0;

    [self setNeedsManualLayout];
    [UIView animateWithDuration:0.25 animations:^{ [self.view layoutIfNeeded]; }];
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    if (self.conversation.messages.count > 0) {
        NSIndexPath *ip = [NSIndexPath indexPathForRow:self.conversation.messages.count - 1 inSection:0];
        [self.tableView scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return self.conversation.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    AIMessage *msg = self.conversation.messages[ip.row];
    BOOL isUser = msg.role == AIMessageRoleUser;

    NSString *id = isUser ? @"UserMessage" : @"AssistantMessage";
    AITerminalMessageView *cell = [tv dequeueReusableCellWithIdentifier:id forIndexPath:ip];
    [cell configureWithMessage:msg theme:_currentTheme];

    // Long press for actions
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    lp.minimumPressDuration = 0.5;
    [cell addGestureRecognizer:lp];

    return cell;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) {
        CGPoint p = [g locationInView:self.tableView];
        NSIndexPath *ip = [self.tableView indexPathForRowAtPoint:p];
        if (ip) {
            AIMessage *msg = self.conversation.messages[ip.row];
            [self showMessageActions:msg atIndexPath:ip];
        }
    }
}

- (void)showMessageActions:(AIMessage *)msg atIndexPath:(NSIndexPath *)ip {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                           destructiveButtonTitle:@"Delete"
                                                otherButtonTitles:@"Copy Text", @"Regenerate", nil];
    sheet.tag = ip.row + 2000;
    [sheet showInView:self.view];
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tv estimatedHeightForRowAtIndexPath:(NSIndexPath *)ip {
    // Cache heights for performance
    static NSMutableDictionary *heightCache;
    if (!heightCache) heightCache = [NSMutableDictionary dictionary];

    NSString *key = [NSString stringWithFormat:@"%@-%lu", self.conversation.conversationID, (unsigned long)ip.row];
    NSNumber *cached = heightCache[key];
    if (cached) return [cached floatValue];

    AIMessage *msg = self.conversation.messages[ip.row];
    CGFloat height = [AITerminalMessageView heightForMessage:msg theme:_currentTheme width:tv.bounds.size.width];
    heightCache[key] = @(height);
    return height;
}

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    return [self tableView:tv estimatedHeightForRowAtIndexPath:ip];
}

- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)ip {
    [_currentTheme styleTableViewCell:cell];
}

#pragma mark - AITerminalInputViewDelegate

- (void)terminalInputView:(AITerminalInputView *)iv didSendText:(NSString *)text attachments:(NSArray<AIAttachment *> *)attachments {
    if (!text.length && !attachments.count) return;

    AIMessage *msg = [AIMessage userMessage:text attachments:attachments];
    [[AIConversationManager sharedManager] addMessage:msg toConversation:self.conversation];
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];

    [[AIAPIManager sharedManager] sendMessage:msg conversationID:self.conversation.conversationID completion:nil];
}

- (void)terminalInputViewDidTapAttach:(AITerminalInputView *)iv {
    [self attachTapped];
}

- (void)terminalInputViewDidTapImageGen:(AITerminalInputView *)iv {
    [self imageGenTapped];
}

- (void)terminalInputViewHeightDidChange:(AITerminalInputView *)iv {
    [self setNeedsManualLayout];
    [self scrollToBottomAnimated:YES];
}

#pragma mark - AIAPIManagerDelegate

- (void)apiManager:(id)m didStartStreamingForMessage:(AIMessage *)msg {
    self.loadingIndicator.hidden = NO;
    [self.loadingIndicator startAnimating];
}

- (void)apiManager:(id)m didReceiveStreamDelta:(NSString *)delta forMessage:(AIMessage *)msg {
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];
}

- (void)apiManager:(id)m didFinishStreamingForMessage:(AIMessage *)msg error:(NSError *)err {
    self.loadingIndicator.hidden = YES;
    [self.loadingIndicator stopAnimating];
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];
    [self updateStatusBar];
}

- (void)apiManager:(id)m didFailToSendMessage:(AIMessage *)msg error:(NSError *)err {
    self.loadingIndicator.hidden = YES;
    [self.loadingIndicator stopAnimating];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                    message:err.localizedDescription
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:@"Retry", nil];
    alert.tag = 888;
    [alert show];
}

- (void)apiManager:(id)m didGenerateImages:(NSArray<NSString *> *)urls error:(NSError *)err {
    if (err) {
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Failed" message:err.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [a show];
        return;
    }
    for (NSString *u in urls) {
        AIAttachment *att = [[AIAttachment alloc] initWithRemoteURL:u mimeType:@"image/png"];
        AIMessage *msg = [AIMessage assistantMessage:[NSString stringWithFormat:@"Generated: %@", u]];
        msg.attachments = @[att];
        [[AIConversationManager sharedManager] addMessage:msg toConversation:self.conversation];
    }
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];
}

#pragma mark - AIConversationManagerDelegate

- (void)conversationManager:(id)m didAddMessage:(AIMessage *)msg toConversation:(NSString *)cid {
    if ([cid isEqualToString:self.conversation.conversationID]) {
        [self.tableView reloadData];
        [self scrollToBottomAnimated:YES];
    }
}

- (void)conversationManager:(id)m didUpdateMessage:(AIMessage *)msg inConversation:(NSString *)cid {
    if ([cid isEqualToString:self.conversation.conversationID]) {
        [self.tableView reloadData];
    }
}

#pragma mark - AITerminalAttachmentPickerDelegate

- (void)attachmentPicker:(id)picker didPickAttachments:(NSArray<AIAttachment *> *)atts {
    self.inputView.attachments = atts;
}

#pragma mark - AITerminalProviderSelectorDelegate

- (void)providerSelector:(id)selector didSelectProvider:(AIProviderType)type {
    // Handled by selector
    self.modelButton.title = [NSString stringWithFormat:@"[ %@ ]", [[AIAPIManager sharedManager] currentModel] ?: @"model"];
}

#pragma mark - AITerminalImageGenDelegate

- (void)imageGenViewController:(id)vc didGenerateImages:(NSArray<NSString *> *)urls {
    // Handled by API manager delegate
}

@end