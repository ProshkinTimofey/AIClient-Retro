//
//  AITerminalProviderSelectorViewController.m
//  AIClient
//
//  Theme-aware provider selector
//

#import "AITerminalProviderSelectorViewController.h"
#import "AIProviderFactory.h"
#import "AIKeychainManager.h"
#import "AITheme.h"

@implementation AITerminalProviderSelectorViewController {
    id<AITheme> _theme;
}

- (instancetype)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Select Provider";
        self.providers = [[AIProviderFactory sharedFactory] registeredProviderTypes];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _theme = [[AIThemeManager sharedManager] currentTheme];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(themeDidChange:)
                                                 name:@"AIThemeDidChangeNotification"
                                               object:nil];

    [self applyTheme];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)themeDidChange:(NSNotification *)note {
    _theme = [[AIThemeManager sharedManager] currentTheme];
    [self applyTheme];
    [self.tableView reloadData];
}

- (void)applyTheme {
    _theme = [[AIThemeManager sharedManager] currentTheme];

    self.view.backgroundColor = _theme.backgroundColor;
    self.tableView.backgroundColor = _theme.backgroundColor;
    self.tableView.separatorColor = _theme.separatorColor;

    [_theme styleNavigationBar:self.navigationController.navigationBar];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"[Cancel]" style:UIBarButtonItemStylePlain target:self action:@selector(cancelTapped)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"[Done]" style:UIBarButtonItemStyleDone target:self action:@selector(doneTapped)];
    [_theme styleBarButton:self.navigationItem.leftBarButtonItem withTheme:_theme];
    [_theme styleBarButton:self.navigationItem.rightBarButtonItem withTheme:_theme];
}

- (void)cancelTapped {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)doneTapped {
    if ([self.delegate respondsToSelector:@selector(terminalProviderSelector:didSelectProvider:)]) {
        [self.delegate terminalProviderSelector:self didSelectProvider:self.selectedProviderType];
    }
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return self.providers.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *id = @"Cell";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:id];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:id];
    }

    [_theme styleTableViewCell:cell];
    cell.textLabel.font = _theme.fontMonospace;
    cell.detailTextLabel.font = _theme.fontCaption;

    AIProviderType type = self.providers[ip.row];
    id<AIProviderProtocol> p = [[AIProviderFactory sharedFactory] createProviderOfType:type];

    cell.textLabel.text = p.providerName;
    [_theme styleLabel:cell.textLabel style:@"monospace"];

    cell.detailTextLabel.text = [self descForType:type];
    [_theme styleLabel:cell.detailTextLabel style:@"caption"];

    // Configured indicator
    NSString *key = [[AIKeychainManager sharedManager] apiKeyForProvider:type error:nil];
    cell.accessoryType = (type == self.selectedProviderType) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.accessoryView = nil;

    if (key.length > 0 && type != self.selectedProviderType) {
        UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 50, 20)];
        badge.font = _theme.fontCaption;
        badge.textColor = _theme.primaryColor;
        badge.textAlignment = NSTextAlignmentCenter;
        badge.text = @"[OK]";
        badge.layer.borderColor = _theme.borderColor.CGColor;
        badge.layer.borderWidth = _theme.borderWidth;
        badge.layer.cornerRadius = _theme.useRoundedCorners ? 3 : 0;
        badge.clipsToBounds = YES;
        cell.accessoryView = badge;
    }

    return cell;
}

- (NSString *)descForType:(AIProviderType)t {
    switch (t) {
        case AIProviderTypeOpenAI: return @"GPT-4o, GPT-4o-mini, DALL-E 3";
        case AIProviderTypeAnthropic: return @"Claude 3.5 Sonnet, Opus, Haiku";
        case AIProviderTypeGemini: return @"Gemini 1.5 Pro, Flash, Imagen 3";
        case AIProviderTypeNVIDIA: return @"Nemotron, Llama, Mistral via NIM";
        case AIProviderTypeCustom: return @"Custom OpenAI-compatible";
        default: return @"";
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    self.selectedProviderType = self.providers[ip.row];
    [tv reloadData];
}

@end