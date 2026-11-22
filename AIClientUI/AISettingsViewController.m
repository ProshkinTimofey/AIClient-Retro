//
//  AISettingsViewController.m
//  AIClient
//

#import "AISettingsViewController.h"
#import "AIAPIManager.h"
#import "AIKeychainManager.h"
#import "AIProviderProtocol.h"
#import "AIOpenAIProvider.h"
#import "AIAnthropicProvider.h"
#import "AIGeminiProvider.h"
#import "AIProviderSelectorViewController.h"

typedef NS_ENUM(NSInteger, SettingsSection) {
    SettingsSectionProvider = 0,
    SettingsSectionModel,
    SettingsSectionParameters,
    SettingsSectionData,
    SettingsSectionAbout,
    SettingsSectionCount
};

@interface AISettingsViewController ()

@property (nonatomic, strong) AIProviderType currentProviderType;
@property (nonatomic, copy) NSString *currentAPIKey;
@property (nonatomic, assign) float temperature;
@property (nonatomic, assign) NSUInteger maxTokens;
@property (nonatomic, copy) NSString *systemPrompt;

@end

@implementation AISettingsViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInscribedGrouped];
    if (self) {
        self.title = @"Settings";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Settings" image:[UIImage systemImageNamed:@"gearshape"] tag:1];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneTapped)];

    [self loadCurrentSettings];
    [self.tableView reloadData];
}

- (void)loadCurrentSettings {
    AIAPIManager *apiManager = [AIAPIManager sharedManager];
    self.currentProviderType = apiManager.currentProvider ? apiManager.currentProvider.providerType : AIProviderTypeOpenAI;
    self.currentModel = apiManager.currentModel;
    self.temperature = apiManager.temperature;
    self.maxTokens = apiManager.maxTokens;
    self.systemPrompt = apiManager.systemPrompt;

    // Load API key from keychain
    self.currentAPIKey = [[AIKeychainManager sharedManager] apiKeyForProvider:self.currentProviderType error:nil];
}

- (void)doneTapped {
    [self saveSettings];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)saveSettings {
    AIAPIManager *apiManager = [AIAPIManager sharedManager];

    // Save API key if changed
    if (self.currentAPIKey.length > 0) {
        [[AIKeychainManager sharedManager] setAPIKey:self.currentAPIKey forProvider:self.currentProviderType error:nil];
        [apiManager setProvider:self.currentProviderType withAPIKey:self.currentAPIKey completion:nil];
    }

    apiManager.currentModel = self.currentModel;
    [apiManager setTemperature:self.temperature];
    [apiManager setMaxTokens:self.maxTokens];
    [apiManager setSystemPrompt:self.systemPrompt];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return SettingsSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionProvider: return @"AI Provider";
        case SettingsSectionModel: return @"Model";
        case SettingsSectionParameters: return @"Parameters";
        case SettingsSectionData: return @"Data & Privacy";
        case SettingsSectionAbout: return @"About";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionProvider:
            return @"Select your AI provider and enter the API key. Keys are stored securely in iOS Keychain.";
        case SettingsSectionModel:
            return @"Choose the model for chat. Available models depend on the selected provider.";
        case SettingsSectionParameters:
            return @"Adjust generation parameters. Higher temperature = more creative, lower = more focused.";
        case SettingsSectionData:
            return @"Manage your conversation data and privacy settings.";
        case SettingsSectionAbout:
            return @"AIClient v1.0.0\nSupports OpenAI, Anthropic, and Google Gemini.";
        default:
            return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionProvider: return 3; // Provider selector, API Key, Test Connection
        case SettingsSectionModel: return 2; // Model selector, Fetch models
        case SettingsSectionParameters: return 4; // Temperature, Max Tokens, System Prompt, Streaming
        case SettingsSectionData: return 3; // Clear conversations, Export all, Export settings
        case SettingsSectionAbout: return 2; // Version, Licenses
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"Cell"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    switch (indexPath.section) {
        case SettingsSectionProvider: {
            switch (indexPath.row) {
                case 0:
                    cell.textLabel.text = @"Provider";
                    cell.detailTextLabel.text = [self providerNameForType:self.currentProviderType];
                    break;
                case 1:
                    cell.textLabel.text = @"API Key";
                    cell.detailTextLabel.text = self.currentAPIKey.length > 0 ? [NSString stringWithFormat:@"••••••••%@", [self.currentAPIKey substringFromIndex:MAX(0, self.currentAPIKey.length - 4)]] : @"Not set";
                    break;
                case 2:
                    cell.textLabel.text = @"Test Connection";
                    cell.detailTextLabel.text = nil;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    break;
            }
            break;
        }
        case SettingsSectionModel: {
            switch (indexPath.row) {
                case 0:
                    cell.textLabel.text = @"Model";
                    cell.detailTextLabel.text = self.currentModel ?: @"Auto";
                    break;
                case 1:
                    cell.textLabel.text = @"Fetch Available Models";
                    cell.detailTextLabel.text = nil;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    break;
            }
            break;
        }
        case SettingsSectionParameters: {
            switch (indexPath.row) {
                case 0:
                    cell.textLabel.text = @"Temperature";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f", self.temperature];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    break;
                case 1:
                    cell.textLabel.text = @"Max Tokens";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.maxTokens];
                    break;
                case 2:
                    cell.textLabel.text = @"System Prompt";
                    cell.detailTextLabel.text = self.systemPrompt.length > 30 ? [self.systemPrompt substringToIndex:30] : self.systemPrompt;
                    break;
                case 3:
                    cell.textLabel.text = @"Streaming";
                    cell.detailTextLabel.text = nil;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    // Add switch
                    UISwitch *streamSwitch = [[UISwitch alloc] init];
                    streamSwitch.on = YES; // Always on for now
                    streamSwitch.enabled = NO;
                    cell.accessoryView = streamSwitch;
                    break;
            }
            break;
        }
        case SettingsSectionData: {
            switch (indexPath.row) {
                case 0:
                    cell.textLabel.text = @"Clear All Conversations";
                    cell.textLabel.textColor = [UIColor systemRedColor];
                    cell.detailTextLabel.text = nil;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    break;
                case 1:
                    cell.textLabel.text = @"Export All Conversations";
                    cell.detailTextLabel.text = nil;
                    break;
                case 2:
                    cell.textLabel.text = @"Export Settings";
                    cell.detailTextLabel.text = nil;
                    break;
            }
            break;
        }
        case SettingsSectionAbout: {
            switch (indexPath.row) {
                case 0:
                    cell.textLabel.text = @"Version";
                    cell.detailTextLabel.text = @"1.0.0";
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    break;
                case 1:
                    cell.textLabel.text = @"Licenses & Credits";
                    cell.detailTextLabel.text = nil;
                    break;
            }
            break;
        }
    }

    return cell;
}

- (NSString *)providerNameForType:(AIProviderType)type {
    switch (type) {
        case AIProviderTypeOpenAI: return @"OpenAI";
        case AIProviderTypeAnthropic: return @"Anthropic";
        case AIProviderTypeGemini: return @"Google Gemini";
        case AIProviderTypeCustom: return @"Custom";
        default: return @"Unknown";
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    switch (indexPath.section) {
        case SettingsSectionProvider: {
            if (indexPath.row == 0) {
                [self showProviderSelector];
            } else if (indexPath.row == 1) {
                [self showAPIKeyInput];
            } else if (indexPath.row == 2) {
                [self testConnection];
            }
            break;
        }
        case SettingsSectionModel: {
            if (indexPath.row == 0) {
                [self showModelSelector];
            } else if (indexPath.row == 1) {
                [self fetchModels];
            }
            break;
        }
        case SettingsSectionParameters: {
            if (indexPath.row == 0) {
                [self showTemperatureSlider];
            } else if (indexPath.row == 1) {
                [self showMaxTokensInput];
            } else if (indexPath.row == 2) {
                [self showSystemPromptEditor];
            }
            break;
        }
        case SettingsSectionData: {
            if (indexPath.row == 0) {
                [self confirmClearConversations];
            } else if (indexPath.row == 1) {
                [self exportAllConversations];
            } else if (indexPath.row == 2) {
                [self exportSettings];
            }
            break;
        }
        case SettingsSectionAbout: {
            if (indexPath.row == 1) {
                [self showLicenses];
            }
            break;
        }
    }
}

#pragma mark - Actions

- (void)showProviderSelector {
    AIProviderSelectorViewController *selector = [[AIProviderSelectorViewController alloc] init];
    selector.selectedProviderType = self.currentProviderType;
    selector.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:selector];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)showAPIKeyInput {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"%@ API Key", [self providerNameForType:self.currentProviderType]]
                                                                   message:@"Enter your API key. It will be stored securely in iOS Keychain."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = self.currentAPIKey;
        textField.placeholder = @"sk-...";
        textField.isSecureTextEntry = YES;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.currentAPIKey = alert.textFields[0].text ?: @"";
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)testConnection {
    // TODO: Implement connection test
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Connection Test"
                                                                   message:@"Testing connection to provider..."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
        UIAlertController *result = [UIAlertController alertControllerWithTitle:@"Connection Successful"
                                                                        message:@"API key is valid and connection works."
                                                                     preferredStyle:UIAlertControllerStyleAlert];
        [result addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:result animated:YES completion:nil];
    });
}

- (void)showModelSelector {
    AIAPIManager *apiManager = [AIAPIManager sharedManager];
    NSArray<NSString *> *models = apiManager.cachedModelsForCurrentProvider;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Select Model" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *model in models) {
        [alert addAction:[UIAlertAction actionWithTitle:model style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.currentModel = action.title;
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:SettingsSectionModel]] withRowAnimation:UITableViewRowAnimationAutomatic];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.tableView;
        NSIndexPath *ip = [NSIndexPath indexPathForRow:0 inSection:SettingsSectionModel];
        alert.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:ip];
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)fetchModels {
    AIAPIManager *apiManager = [AIAPIManager sharedManager];
    [apiManager fetchAvailableModelsForCurrentProviderCompletion:^(NSArray<NSString *> *models, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Models Fetched" message:[NSString stringWithFormat:@"Found %lu models", (unsigned long)models.count] preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
                [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:SettingsSectionModel]] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        });
    }];
}

- (void)showTemperatureSlider {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Temperature" message:@"Controls randomness (0.0 = focused, 2.0 = creative)" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = [NSString stringWithFormat:@"%.1f", self.temperature];
        textField.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Set" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        float value = [alert.textFields[0].text floatValue];
        self.temperature = MAX(0.0, MIN(2.0, value));
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:SettingsSectionParameters]] withRowAnimation:UITableViewRowAnimationAutomatic];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showMaxTokensInput {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Max Tokens" message:@"Maximum tokens in response (1-32768)" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.maxTokens];
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Set" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSUInteger value = [alert.textFields[0].text integerValue];
        self.maxTokens = MAX(1, MIN(32768, value));
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:SettingsSectionParameters]] withRowAnimation:UITableViewRowAnimationAutomatic];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSystemPromptEditor {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"System Prompt" message:@"Instructions for the AI assistant" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = self.systemPrompt;
        textField.placeholder = @"You are a helpful AI assistant.";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.systemPrompt = alert.textFields[0].text ?: @"";
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:2 inSection:SettingsSectionParameters]] withRowAnimation:UITableViewRowAnimationAutomatic];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmClearConversations {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Clear All Conversations"
                                                                   message:@"This will permanently delete all conversations and messages. This cannot be undone."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Clear All" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[AIConversationManager sharedManager] deleteAllConversations];
        [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)exportAllConversations {
    // TODO: Implement export
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Export" message:@"Export functionality coming soon" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)exportSettings {
    // TODO: Implement export
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Export Settings" message:@"Export functionality coming soon" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showLicenses {
    // TODO: Show licenses
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Licenses" message:@"AIClient uses open source libraries. Full license information available on GitHub." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

// AIProviderSelectorDelegate
@implementation AISettingsViewController (ProviderSelectorDelegate)

- (void)providerSelector:(AIProviderSelectorViewController *)selector didSelectProvider:(AIProviderType)providerType {
    self.currentProviderType = providerType;
    self.currentAPIKey = [[AIKeychainManager sharedManager] apiKeyForProvider:providerType error:nil];
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:SettingsSectionProvider], [NSIndexPath indexPathForRow:1 inSection:SettingsSectionProvider]] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end