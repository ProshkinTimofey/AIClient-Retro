//
//  AIProviderSelectorViewController.m
//  AIClient
//

#import "AIProviderSelectorViewController.h"
#import "AIProviderFactory.h"
#import "AIKeychainManager.h"

@interface AIProviderSelectorViewController ()

@property (nonatomic, strong) NSArray<AIProviderType> *availableProviders;

@end

@implementation AIProviderSelectorViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInscribedGrouped];
    if (self) {
        self.title = @"Select Provider";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelTapped)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneTapped)];

    self.availableProviders = [[AIProviderFactory sharedFactory] registeredProviderTypes];
    [self.tableView reloadData];
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)doneTapped {
    if ([self.delegate respondsToSelector:@selector(providerSelector:didSelectProvider:)]) {
        [self.delegate providerSelector:self didSelectProvider:self.selectedProviderType];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.availableProviders.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    AIProviderType type = self.availableProviders[indexPath.row];
    id<AIProviderProtocol> provider = [[AIProviderFactory sharedFactory] createProviderOfType:type];

    cell.textLabel.text = provider.providerName;
    cell.detailTextLabel.text = [self descriptionForProvider:type];

    // Check if configured
    NSString *key = [[AIKeychainManager sharedManager] apiKeyForProvider:type error:nil];
    if (key.length > 0) {
        cell.imageView.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
        cell.imageView.tintColor = [UIColor systemGreenColor];
    } else {
        cell.imageView.image = [UIImage systemImageNamed:@"circle"];
        cell.imageView.tintColor = [UIColor tertiaryLabel];
    }

    // Selection indicator
    if (type == self.selectedProviderType) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

- (NSString *)descriptionForProvider:(AIProviderType)type {
    switch (type) {
        case AIProviderTypeOpenAI:
            return @"GPT-4o, GPT-4o-mini, DALL-E 3";
        case AIProviderTypeAnthropic:
            return @"Claude 3.5 Sonnet, Opus, Haiku";
        case AIProviderTypeGemini:
            return @"Gemini 1.5 Pro, Flash, Imagen 3";
        case AIProviderTypeCustom:
            return @"Custom OpenAI-compatible endpoint";
        default:
            return @"";
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    self.selectedProviderType = self.availableProviders[indexPath.row];
    [tableView reloadData];
}

@end