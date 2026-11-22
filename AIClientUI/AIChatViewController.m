//
//  AIChatViewController.m
//  AIClient
//

#import "AIChatViewController.h"
#import "AIMessage.h"
#import "AIAttachment.h"
#import "AIAPIManager.h"
#import "AIConversationManager.h"
#import "AIMessageCell.h"
#import "AIChatInputView.h"
#import "AIAttachmentPickerViewController.h"
#import "AIImageGenerationViewController.h"
#import "AIProviderSelectorViewController.h"
#import "AIStreamingIndicatorView.h"

@interface AIChatViewController ()

@property (nonatomic, strong) AIConversation *conversation;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) AIChatInputView *inputView;
@property (nonatomic, strong) NSLayoutConstraint *inputViewBottomConstraint;
@property (nonatomic, strong) AIStreamingIndicatorView *streamingIndicator;
@property (nonatomic, strong) UIBarButtonItem *modelButton;
@property (nonatomic, strong) UIBarButtonItem *attachButton;
@property (nonatomic, strong) UIBarButtonItem *imageGenButton;
@property (nonatomic, strong) UIBarButtonItem *moreButton;
@property (nonatomic, assign) BOOL isKeyboardVisible;
@property (nonatomic, assign) CGFloat keyboardHeight;

@end

@implementation AIChatViewController

- (instancetype)initWithConversation:(AIConversation *)conversation {
    self = [super init];
    if (self) {
        _conversation = conversation;
        self.title = conversation.title;
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupTableView];
    [self setupInputView];
    [self setupNavigationBar];
    [self setupKeyboardObservers];
    [self setupDelegates];
    [self loadMessages];

    // Register for API manager delegate
    [[AIAPIManager sharedManager] setDelegate:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:NO animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setToolbarHidden:YES animated:animated];
    [[AIAPIManager sharedManager] setDelegate:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor systemBackgroundColor];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.contentInset = UIEdgeInsetsMake(16, 0, 16, 0);
    self.tableView.registerClass:[AIMessageCell class] forCellReuseIdentifier:@"MessageCell"];
    self.tableView.registerClass:[AIMessageCell class] forCellReuseIdentifier:@"UserMessageCell"];
    [self.view addSubview:self.tableView];
}

- (void)setupInputView {
    self.inputView = [[AIChatInputView alloc] initWithFrame:CGRectZero];
    self.inputView.delegate = self;
    self.inputView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.inputView];

    self.inputViewBottomConstraint = [self.inputView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor];
    [NSLayoutConstraint activateConstraints:@[
        self.inputView.leadingAnchor.constraintEqualToAnchor:self.view.leadingAnchor,
        self.inputView.trailingAnchor.constraintEqualToAnchor:self.view.trailingAnchor,
        self.inputViewBottomConstraint,
    ]];

    // Streaming indicator
    self.streamingIndicator = [[AIStreamingIndicatorView alloc] initWithFrame:CGRectZero];
    self.streamingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.streamingIndicator.hidden = YES;
    [self.view addSubview:self.streamingIndicator];

    [NSLayoutConstraint activateConstraints:@[
        self.streamingIndicator.leadingAnchor.constraintEqualToAnchor:self.view.leadingAnchor,
        self.streamingIndicator.trailingAnchor.constraintEqualToAnchor:self.view.trailingAnchor,
        self.streamingIndicator.bottomAnchor.constraintEqualToAnchor:self.inputView.topAnchor,
        self.streamingIndicator.heightAnchor.constraintEqualToConstant:4,
    ]];
}

- (void)setupNavigationBar {
    // Model selector button
    self.modelButton = [[UIBarButtonItem alloc] initWithTitle:[[AIAPIManager sharedManager] currentModel] style:UIBarButtonItemStylePlain target:self action:@selector(modelButtonTapped)];
    self.modelButton.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];

    // Attach button
    self.attachButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"paperclip"] style:UIBarButtonItemStylePlain target:self action:@selector(attachButtonTapped)];

    // Image generation button
    self.imageGenButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"sparkles"] style:UIBarButtonItemStylePlain target:self action:@selector(imageGenButtonTapped)];

    // More button
    self.moreButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"] style:UIBarButtonItemStylePlain target:self action:@selector(moreButtonTapped)];

    self.navigationItem.rightBarButtonItems = @[self.moreButton, self.imageGenButton, self.attachButton, self.modelButton];
}

- (void)setupDelegates {
    [[AIConversationManager sharedManager] setDelegate:self];
}

- (void)setupKeyboardObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidChangeFrame:) name:UIKeyboardDidChangeFrameNotification object:nil];
}

- (void)loadMessages {
    // Messages are already loaded in conversation
    [self.tableView reloadData];
    [self scrollToBottomAnimated:NO];
}

#pragma mark - Actions

- (void)modelButtonTapped {
    AIProviderSelectorViewController *selector = [[AIProviderSelectorViewController alloc] init];
    selector.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:selector];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)attachButtonTapped {
    AIAttachmentPickerViewController *picker = [[AIAttachmentPickerViewController alloc] init];
    picker.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)imageGenButtonTapped {
    AIImageGenerationViewController *imageGenVC = [[AIImageGenerationViewController alloc] init];
    imageGenVC.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:imageGenVC];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)moreButtonTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:@"Clear Conversation" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self confirmClearConversation];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Export Conversation" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self exportConversation];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Conversation Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showConversationSettings];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    // For iPad
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.barButtonItem = self.moreButton;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmClearConversation {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Clear Conversation"
                                                                   message:@"This will remove all messages but keep the conversation."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Clear" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        self.conversation.messages = @[];
        [[AIConversationManager sharedManager] saveAllConversations];
        [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)exportConversation {
    NSData *data = [[AIConversationManager sharedManager] exportConversation:self.conversation error:nil];
    if (data) {
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[data] applicationActivities:nil];
        [self presentViewController:activityVC animated:YES completion:nil];
    }
}

- (void)showConversationSettings {
    // TODO: Implement conversation settings (system prompt, model, temperature, etc.)
}

#pragma mark - Keyboard Handling

- (void)keyboardWillShow:(NSNotification *)notification {
    self.isKeyboardVisible = YES;
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    keyboardFrame = [self.view convertRect:keyboardFrame fromView:nil];
    self.keyboardHeight = keyboardFrame.size.height;

    self.inputViewBottomConstraint.constant = -keyboardFrame.size.height + self.view.safeAreaInsets.bottom;
    [UIView animateWithDuration:0.25 animations:^{
        [self.view layoutIfNeeded];
    }];
    [self scrollToBottomAnimated:YES];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.isKeyboardVisible = NO;
    self.inputViewBottomConstraint.constant = 0;
    [UIView animateWithDuration:0.25 animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)keyboardDidChangeFrame:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    keyboardFrame = [self.view convertRect:keyboardFrame fromView:nil];
    self.keyboardHeight = keyboardFrame.size.height;

    self.inputViewBottomConstraint.constant = -keyboardFrame.size.height + self.view.safeAreaInsets.bottom;
    [self.view layoutIfNeeded];
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    if (self.conversation.messages.count > 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.conversation.messages.count - 1 inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.conversation.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AIMessage *message = self.conversation.messages[indexPath.row];
    BOOL isUser = message.role == AIMessageRoleUser;

    NSString *identifier = isUser ? @"UserMessageCell" : @"MessageCell";
    AIMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
    [cell configureWithMessage:message];

    // Long press for copy/menu
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.5;
    [cell addGestureRecognizer:longPress];

    return cell;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [gesture locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
        if (indexPath) {
            AIMessage *message = self.conversation.messages[indexPath.row];
            [self showMessageActionsForMessage:message atIndexPath:indexPath];
        }
    }
}

- (void)showMessageActionsForMessage:(AIMessage *)message atIndexPath:(NSIndexPath *)indexPath {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:@"Copy Text" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[UIPasteboard generalPasteboard] setString:message.content];
    }]];

    if (message.role == AIMessageRoleAssistant) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Regenerate" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self regenerateResponseForMessage:message];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self.conversation.messages removeObject:message];
        [[AIConversationManager sharedManager] updateConversation:self.conversation];
        [self.tableView reloadData];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    if (alert.popoverPresentationController) {
        AIMessageCell *cell = (AIMessageCell *)[self.tableView cellForRowAtIndexPath:indexPath];
        alert.popoverPresentationController.sourceView = cell;
        alert.popoverPresentationController.sourceRect = cell.bounds;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)regenerateResponseForMessage:(AIMessage *)assistantMessage {
    // Find the user message before this assistant message
    NSUInteger index = [self.conversation.messages indexOfObject:assistantMessage];
    if (index > 0) {
        AIMessage *userMessage = self.conversation.messages[index - 1];
        if (userMessage.role == AIMessageRoleUser) {
            // Remove the assistant message
            [self.conversation.messages removeObject:assistantMessage];

            // Retry sending
            [[AIAPIManager sharedManager] sendMessage:userMessage conversationID:self.conversation.conversationID completion:nil];
        }
    }
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 80;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

#pragma mark - AIChatInputViewDelegate

- (void)chatInputView:(AIChatInputView *)inputView didSendText:(NSString *)text attachments:(NSArray<AIAttachment *> *)attachments {
    if (text.length == 0 && attachments.count == 0) return;

    AIMessage *message = [AIMessage userMessage:text attachments:attachments];
    [[AIConversationManager sharedManager] addMessage:message toConversation:self.conversation];
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];

    [[AIAPIManager sharedManager] sendMessage:message conversationID:self.conversation.conversationID completion:nil];
}

- (void)chatInputViewDidTapAttach:(AIChatInputView *)inputView {
    [self attachButtonTapped];
}

- (void)chatInputViewDidTapImageGen:(AIChatInputView *)inputView {
    [self imageGenButtonTapped];
}

- (void)chatInputViewHeightDidChange:(AIChatInputView *)inputView {
    [self.view layoutIfNeeded];
    [self scrollToBottomAnimated:YES];
}

#pragma mark - AIAPIManagerDelegate

- (void)apiManager:(id)manager didStartStreamingForMessage:(AIMessage *)message {
    self.streamingIndicator.hidden = NO;
    [self.streamingIndicator startAnimating];
}

- (void)apiManager:(id)manager didReceiveStreamDelta:(NSString *)delta forMessage:(AIMessage *)message {
    // Streaming handled by AIAPIManager, just update UI
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];
}

- (void)apiManager:(id)manager didFinishStreamingForMessage:(AIMessage *)message error:(NSError *)error {
    self.streamingIndicator.hidden = YES;
    [self.streamingIndicator stopAnimating];
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];
}

- (void)apiManager:(id)manager didFailToSendMessage:(AIMessage *)message error:(NSError *)error {
    self.streamingIndicator.hidden = YES;
    [self.streamingIndicator stopAnimating];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                   message:error.localizedDescription
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Retry" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[AIAPIManager sharedManager] retryLastMessage];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)apiManager:(id)manager didGenerateImages:(NSArray<NSString *> *)imageURLs error:(NSError *)error {
    if (error) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Generation Failed"
                                                                       message:error.localizedDescription
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // Show generated images
    for (NSString *url in imageURLs) {
        AIAttachment *attachment = [[AIAttachment alloc] initWithRemoteURL:url mimeType:@"image/png"];
        AIMessage *message = [AIMessage assistantMessage:[NSString stringWithFormat:@"Generated image: %@", url]];
        message.attachments = @[attachment];
        [[AIConversationManager sharedManager] addMessage:message toConversation:self.conversation];
    }
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];
}

- (void)apiManager:(id)manager didUploadAttachment:(AIAttachment *)attachment progress:(float)progress {
    // Update attachment cell progress
}

- (void)apiManager:(id)manager didFinishUploadingAttachment:(AIAttachment *)attachment error:(NSError *)error {
    // Attachment uploaded, will be included in next message
}

#pragma mark - AIConversationManagerDelegate

- (void)conversationManager:(id)manager didAddMessage:(AIMessage *)message toConversation:(NSString *)conversationID {
    if ([conversationID isEqualToString:self.conversation.conversationID]) {
        [self.tableView reloadData];
        [self scrollToBottomAnimated:YES];
    }
}

- (void)conversationManager:(id)manager didUpdateMessage:(AIMessage *)message inConversation:(NSString *)conversationID {
    if ([conversationID isEqualToString:self.conversation.conversationID]) {
        [self.tableView reloadData];
    }
}

@end