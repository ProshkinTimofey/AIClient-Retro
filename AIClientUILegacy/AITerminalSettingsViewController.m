//
//  AITerminalSettingsViewController.m
//  AIClient
//
//  Theme-aware settings with Proxy URL and Theme selector
//

#import "AITerminalSettingsViewController.h"
#import "AIAPIManager.h"
#import "AIKeychainManager.h"
#import "AIProviderProtocol.h"
#import "AIProviderFactory.h"
#import "AITerminalProviderSelectorViewController.h"
#import "AITheme.h"

typedef NS_ENUM(NSInteger, SettingsSection) {
    SectionProvider = 0,
    SectionModel,
    SectionParams,
    SectionProxy,
    SectionTheme,
    SectionData,
    SectionAbout,
    SectionCount
};

@interface AITerminalSettingsViewController ()

@property (nonatomic, assign) AIProviderType currentProviderType;
@property (nonatomic, copy) NSString *currentAPIKey;
@property (nonatomic, copy) NSString *currentModel;
@property (nonatomic, assign) float temperature;
@property (nonatomic, assign) NSUInteger maxTokens;
@property (nonatomic, copy) NSString *systemPrompt;
@property (nonatomic, copy) NSString *proxyURL;
@property (nonatomic, assign) AIThemeType currentThemeType;
@property (nonatomic, strong) id<AITheme> currentTheme;

@end

@implementation AITerminalSettingsViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"Settings";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Settings" image:nil tag:1];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _currentTheme = [[AIThemeManager sharedManager] currentTheme];
    _currentThemeType = [[AIThemeManager sharedManager] currentThemeType];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(themeDidChange:)
                                                 name:@"AIThemeDidChangeNotification"
                                               object:nil];

    [self applyTheme];
    [self loadSettings];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)themeDidChange:(NSNotification *)note {
    _currentTheme = [[AIThemeManager sharedManager] currentTheme];
    _currentThemeType = [[AIThemeManager sharedManager] currentThemeType];
    [self applyTheme];
    [self.tableView reloadData];
}

- (void)applyTheme {
    id<AITheme> theme = _currentTheme;

    self.view.backgroundColor = theme.backgroundColor;
    self.tableView.backgroundColor = theme.backgroundColor;
    self.tableView.separatorColor = theme.separatorColor;

    [theme styleNavigationBar:self.navigationController.navigationBar];

    // Done button
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"[Done]" style:UIBarButtonItemStyleDone target:self action:@selector(doneTapped)];
    [theme styleBarButton:self.navigationItem.leftBarButtonItem withTheme:theme];
}

- (void)loadSettings {
    AIAPIManager *api = [AIAPIManager sharedManager];
    self.currentProviderType = api.currentProvider ? api.currentProvider.providerType : AIProviderTypeOpenAI;
    self.currentModel = api.currentModel;
    self.temperature = api.temperature;
    self.maxTokens = api.maxTokens;
    self.systemPrompt = api.systemPrompt;
    self.currentAPIKey = [[AIKeychainManager sharedManager] apiKeyForProvider:self.currentProviderType error:nil];
    self.proxyURL = [api proxyURL] ?: @"";
}

- (void)doneTapped {
    [self saveSettings];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)saveSettings {
    AIAPIManager *api = [AIAPIManager sharedManager];
    if (self.currentAPIKey.length > 0) {
        [[AIKeychainManager sharedManager] setAPIKey:self.currentAPIKey forProvider:self.currentProviderType error:nil];
        [api setProvider:self.currentProviderType withAPIKey:self.currentAPIKey completion:nil];
    }
    api.currentModel = self.currentModel;
    [api setTemperature:self.temperature];
    [api setMaxTokens:self.maxTokens];
    [api setSystemPrompt:self.systemPrompt];
    [api setProxyURL:self.proxyURL];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
    return SectionCount;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    id<AITheme> theme = _currentTheme;
    switch (s) {
        case SectionProvider: return [theme styleSectionHeader:@"PROVIDER"];
        case SectionModel: return [theme styleSectionHeader:@"MODEL"];
        case SectionParams: return [theme styleSectionHeader:@"PARAMETERS"];
        case SectionProxy: return [theme styleSectionHeader:@"PROXY (TLS)"];
        case SectionTheme: return [theme styleSectionHeader:@"THEME"];
        case SectionData: return [theme styleSectionHeader:@"DATA"];
        case SectionAbout: return [theme styleSectionHeader:@"ABOUT"];
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    switch (s) {
        case SectionProvider: return @"Select AI provider and enter API key. Stored in iOS Keychain.";
        case SectionModel: return @"Choose model for chat. Available models depend on provider.";
        case SectionParams: return @"Temperature: 0.0 = focused, 2.0 = creative. Max tokens: 1-32768.";
        case SectionProxy: return @"TLS proxy URL for iOS 6 (e.g., https://proxy.example.com). Terminates TLS 1.2+ and forwards via TLS 1.0.";
        case SectionTheme: return @"Visual theme. Skeuomorphic = iOS 6 leather/metal. Minimalist = iOS 13+. Claude Code = terminal mono.";
        case SectionData: return @"Manage conversations and export data.";
        case SectionAbout: return @"AIClient v1.0.0 (iOS 6 Terminal)\nOpenAI, Anthropic, Google Gemini, NVIDIA NIM";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    switch (s) {
        case SectionProvider: return 3;
        case SectionModel: return 2;
        case SectionParams: return 4;
        case SectionProxy: return 2;
        case SectionTheme: return 3;
        case SectionData: return 3;
        case SectionAbout: return 2;
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cellId = @"Cell";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
    }

    [self.currentTheme styleTableViewCell:cell];
    cell.textLabel.font = self.currentTheme.fontMonospace;
    cell.detailTextLabel.font = self.currentTheme.fontCaption;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    switch (ip.section) {
        case SectionProvider:
            switch (ip.row) {
                case 0:
                    cell.textLabel.text = @"> provider";
                    id<AIProviderProtocol> p = [[AIProviderFactory sharedFactory] createProviderOfType:self.currentProviderType];
                    cell.detailTextLabel.text = p ? p.providerName : @"Unknown";
                    break;
                case 1:
                    cell.textLabel.text = @"> api_key";
                    cell.detailTextLabel.text = self.currentAPIKey.length > 0 ? [NSString stringWithFormat:@"***%@", [self.currentAPIKey substringFromIndex:MAX(0, (NSInteger)self.currentAPIKey.length - 4)]] : @"<not set>";
                    break;
                case 2:
                    cell.textLabel.text = @"> test_connection";
                    cell.detailTextLabel.text = @"";
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    break;
            }
            break;
        case SectionModel:
            switch (ip.row) {
                case 0:
                    cell.textLabel.text = @"> model";
                    cell.detailTextLabel.text = self.currentModel ?: @"<auto>";
                    break;
                case 1:
                    cell.textLabel.text = @"> fetch_models";
                    cell.detailTextLabel.text = @"";
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    break;
            }
            break;
        case SectionParams:
            switch (ip.row) {
                case 0:
                    cell.textLabel.text = @"> temperature";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f", self.temperature];
                    break;
                case 1:
                    cell.textLabel.text = @"> max_tokens";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.maxTokens];
                    break;
                case 2:
                    cell.textLabel.text = @"> system_prompt";
                    cell.detailTextLabel.text = self.systemPrompt.length > 20 ? [self.systemPrompt substringToIndex:20] : (self.systemPrompt.length > 0 ? self.systemPrompt : @"<empty>");
                    break;
                case 3:
                    cell.textLabel.text = @"> streaming";
                    cell.detailTextLabel.text = @"enabled";
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    break;
            }
            break;
        case SectionProxy:
            switch (ip.row) {
                case 0:
                    cell.textLabel.text = @"> proxy_url";
                    cell.detailTextLabel.text = self.proxyURL.length > 0 ? self.proxyURL : @"<none>";
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    break;
                case 1:
                    cell.textLabel.text = @"> test_proxy";
                    cell.detailTextLabel.text = @"";
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    break;
            }
            break;
        case SectionTheme:
            switch (ip.row) {
                case 0:
                    cell.textLabel.text = @"> theme";
                    cell.detailTextLabel.text = [self themeNameForType:self.currentThemeType];
                    break;
                case 1:
                    cell.textLabel.text = @"> select_theme";
                    cell.detailTextLabel.text = @"";
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    break;
                case 2:
                    cell.textLabel.text = @"> animated_switch";
                    cell.detailTextLabel.text = @"enabled";
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    break;
            }
            break;
        case SectionData:
            switch (ip.row) {
                case 0:
                    cell.textLabel.text = @"> clear_all_chats";
                    cell.textLabel.textColor = self.currentTheme.errorColor;
                    cell.detailTextLabel.text = @"";
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    break;
                case 1:
                    cell.textLabel.text = @"> export_all";
                    cell.detailTextLabel.text = @"";
                    break;
                case 2:
                    cell.textLabel.text = @"> export_config";
                    cell.detailTextLabel.text = @"";
                    break;
            }
            break;
        case SectionAbout:
            switch (ip.row) {
                case 0:
                    cell.textLabel.text = @"> version";
                    cell.detailTextLabel.text = @"1.0.0";
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    break;
                case 1:
                    cell.textLabel.text = @"> licenses";
                    cell.detailTextLabel.text = @"";
                    break;
            }
            break;
    }
    return cell;
}

- (NSString *)themeNameForType:(AIThemeType)type {
    switch (type) {
        case AIThemeTypeSkeuomorphic: return @"Skeuomorphic (iOS 6)";
        case AIThemeTypeMinimalist: return @"Minimalist (iOS 13+)";
        case AIThemeTypeClaudeCode: return @"Claude Code (Terminal)";
        default: return @"Unknown";
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];

    switch (ip.section) {
        case SectionProvider:
            if (ip.row == 0) [self showProviderSelector];
            else if (ip.row == 1) [self showAPIKeyInput];
            else if (ip.row == 2) [self testConnection];
            break;
        case SectionModel:
            if (ip.row == 0) [self showModelSelector];
            else if (ip.row == 1) [self fetchModels];
            break;
        case SectionParams:
            if (ip.row == 0) [self showTempInput];
            else if (ip.row == 1) [self showTokensInput];
            else if (ip.row == 2) [self showPromptInput];
            break;
        case SectionProxy:
            if (ip.row == 0) [self showProxyURLInput];
            else if (ip.row == 1) [self testProxy];
            break;
        case SectionTheme:
            if (ip.row == 0) [self showThemeSelector];
            else if (ip.row == 1) [self showThemeSelector];
            break;
        case SectionData:
            if (ip.row == 0) [self confirmClear];
            else if (ip.row == 1) [self exportAll];
            else if (ip.row == 2) [self exportConfig];
            break;
        case SectionAbout:
            if (ip.row == 1) [self showLicenses];
            break;
    }
}

#pragma mark - Actions

- (void)showProviderSelector {
    AITerminalProviderSelectorViewController *vc = [[AITerminalProviderSelectorViewController alloc] init];
    vc.selectedProviderType = self.currentProviderType;
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showAPIKeyInput {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"API Key"
                                                    message:@"Enter API key for provider"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Save", nil];
    alert.alertViewStyle = UIAlertViewStyleSecureTextInput;
    alert.tag = 100;
    [alert textFieldAtIndex:0].text = self.currentAPIKey;
    [alert textFieldAtIndex:0].placeholder = @"sk-...";
    [self.currentTheme styleAlertView:alert];
    [alert show];
}

- (void)testConnection {
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"> testing..." message:@"Connecting to provider..." delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    [self.currentTheme styleAlertView:a];
    [a show];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [a dismissWithClickedButtonIndex:0 animated:YES];
        UIAlertView *r = [[UIAlertView alloc] initWithTitle:@"> ok" message:@"Connection successful" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [self.currentTheme styleAlertView:r];
        [r show];
    });
}

- (void)showModelSelector {
    AIAPIManager *api = [AIAPIManager sharedManager];
    NSArray *models = api.cachedModelsForCurrentProvider;

    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"> select model" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil];
    for (NSString *m in models) {
        [sheet addButtonWithTitle:m];
    }
    sheet.tag = 200;
    [self.currentTheme styleActionSheet:sheet];
    [sheet showInView:self.view];
}

- (void)fetchModels {
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"> fetching..." message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    [self.currentTheme styleAlertView:a];
    [a show];
    [[AIAPIManager sharedManager] fetchAvailableModelsForCurrentProviderCompletion:^(NSArray *models, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [a dismissWithClickedButtonIndex:0 animated:YES];
            UIAlertView *r = [[UIAlertView alloc] initWithTitle:err ? @"> error" : @"> done" message:err ? err.localizedDescription : [NSString stringWithFormat:@"Found %lu models", (unsigned long)models.count] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [self.currentTheme styleAlertView:r];
            [r show];
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:SectionModel]] withRowAnimation:UITableViewRowAnimationAutomatic];
        });
    }];
}

- (void)showTempInput {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"> temperature (0.0-2.0)" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Set", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = 101;
    [alert textFieldAtIndex:0].text = [NSString stringWithFormat:@"%.1f", self.temperature];
    [alert textFieldAtIndex:0].keyboardType = UIKeyboardTypeDecimalPad;
    [self.currentTheme styleAlertView:alert];
    [alert show];
}

- (void)showTokensInput {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"> max tokens (1-32768)" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Set", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = 102;
    [alert textFieldAtIndex:0].text = [NSString stringWithFormat:@"%lu", (unsigned long)self.maxTokens];
    [alert textFieldAtIndex:0].keyboardType = UIKeyboardTypeNumberPad;
    [self.currentTheme styleAlertView:alert];
    [alert show];
}

- (void)showPromptInput {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"> system prompt" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = 103;
    [alert textFieldAtIndex:0].text = self.systemPrompt;
    [self.currentTheme styleAlertView:alert];
    [alert show];
}

- (void)showProxyURLInput {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"> proxy url" message:@"TLS proxy endpoint (e.g., https://proxy.example.com)" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = 104;
    [alert textFieldAtIndex:0].text = self.proxyURL;
    [alert textFieldAtIndex:0].placeholder = @"https://proxy.example.com";
    [alert textFieldAtIndex:0].autocapitalizationType = UITextAutocapitalizationTypeNone;
    [alert textFieldAtIndex:0].autocorrectionType = UITextAutocorrectionTypeNo;
    [self.currentTheme styleAlertView:alert];
    [alert show];
}

- (void)testProxy {
    UIAlertView *a = [[UIAlertView alloc] initWithTitle="@> testing proxy..." message:@"Connecting to proxy..." delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    [self.currentTheme styleAlertView:a];
    [a show];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [a dismissWithClickedButtonIndex:0 animated:YES];
        UIAlertView *r = [[UIAlertView alloc] initWithTitle="@> ok" message:@"Proxy reachable" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [self.currentTheme styleAlertView:r];
        [r show];
    });
}

- (void)showThemeSelector {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"> select theme"
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                           destructiveButtonTitle:nil
                                                otherButtonTitles:@"Skeuomorphic (iOS 6)", @"Minimalist (iOS 13+)", @"Claude Code (Terminal)", nil];
    sheet.tag = 300;
    [self.currentTheme styleActionSheet:sheet];
    [sheet showInView:self.view];
}

- (void)confirmClear {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"> clear all"
                                                    message:@"Delete all conversations? Irreversible."
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Clear", nil];
    alert.tag = 999;
    [self.currentTheme styleAlertView:alert];
    [alert show];
}

- (void)exportAll { /* TODO */ }
- (void)exportConfig { /* TODO */ }
- (void)showLicenses { /* TODO */ }

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)btn {
    if (btn == alert.cancelButtonIndex) return;

    switch (alert.tag) {
        case 100: // API Key
            self.currentAPIKey = [alert textFieldAtIndex:0].text ?: @"";
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:SectionProvider]] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        case 101: // Temperature
            self.temperature = MAX(0, MIN(2, [[alert textFieldAtIndex:0].text floatValue]));
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:SectionParams]] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        case 102: // Max Tokens
            self.maxTokens = MAX(1, MIN(32768, [[alert textFieldAtIndex:0].text integerValue]));
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:SectionParams]] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        case 103: // System Prompt
            self.systemPrompt = [alert textFieldAtIndex:0].text ?: @"";
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:2 inSection:SectionParams]] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        case 104: // Proxy URL
            self.proxyURL = [alert textFieldAtIndex:0].text ?: @"";
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:SectionProxy]] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        case 200: // Model
            self.currentModel = [alert buttonTitleAtIndex:btn];
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:SectionModel]] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        case 300: // Theme
            if (btn == 0) [[AIThemeManager sharedManager] setThemeType:AIThemeTypeSkeuomorphic animated:YES];
            else if (btn == 1) [[AIThemeManager sharedManager] setThemeType:AIThemeTypeMinimalist animated:YES];
            else if (btn == 2) [[AIThemeManager sharedManager] setThemeType:AIThemeTypeClaudeCode animated:YES];
            break;
        case 999: // Clear All
            [[AIConversationManager sharedManager] deleteAllConversations];
            break;
    }
}

#pragma mark - Provider Selector Delegate

- (void)terminalProviderSelector:(AITerminalProviderSelectorViewController *)sel didSelectProvider:(AIProviderType)type {
    self.currentProviderType = type;
    self.currentAPIKey = [[AIKeychainManager sharedManager] apiKeyForProvider:type error:nil];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:SectionProvider] withRowAnimation:UITableViewRowAnimationAutomatic];
}

@end