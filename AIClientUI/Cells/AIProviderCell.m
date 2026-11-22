//
//  AIProviderCell.m
//  AIClient
//

#import "AIProviderCell.h"
#import "AIProviderFactory.h"
#import "AIKeychainManager.h"

@interface AIProviderCell ()

@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIImageView *checkmarkImageView;

@end

@implementation AIProviderCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    // Icon
    self.iconImageView = [[UIImageView alloc] init];
    self.iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconImageView.layer.cornerRadius = 8;
    self.iconImageView.clipsToBounds = YES;
    [self.contentView addSubview:self.iconImageView];

    // Name
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.nameLabel.textColor = [UIColor label];
    [self.contentView addSubview:self.nameLabel];

    // Status
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.statusLabel.textColor = [UIColor secondaryLabel];
    [self.contentView addSubview:self.statusLabel];

    // Checkmark
    self.checkmarkImageView = [[UIImageView alloc] init];
    self.checkmarkImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.checkmarkImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.checkmarkImageView.tintColor = [UIColor systemBlueColor];
    [self.contentView addSubview:self.checkmarkImageView];

    [NSLayoutConstraint activateConstraints:@[
        self.iconImageView.leadingAnchor.constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        self.iconImageView.centerYAnchor.constraintEqualToAnchor:self.contentView.centerYAnchor],
        self.iconImageView.widthAnchor.constraintEqualToConstant(40)],
        self.iconImageView.heightAnchor.constraintEqualToConstant(40)],

        self.nameLabel.leadingAnchor.constraintEqualToAnchor:self.iconImageView.trailingAnchor constant:12],
        self.nameLabel.topAnchor.constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        self.nameLabel.trailingAnchor.constraintEqualToAnchor:self.checkmarkImageView.leadingAnchor constant:-8],

        self.statusLabel.leadingAnchor.constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        self.statusLabel.topAnchor.constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:2],
        self.statusLabel.trailingAnchor.constraintEqualToAnchor:self.nameLabel.trailingAnchor],
        self.statusLabel.bottomAnchor.constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],

        self.checkmarkImageView.trailingAnchor.constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        self.checkmarkImageView.centerYAnchor.constraintEqualToAnchor:self.contentView.centerYAnchor],
        self.checkmarkImageView.widthAnchor.constraintEqualToConstant(24)],
        self.checkmarkImageView.heightAnchor.constraintEqualToConstant(24)],
    ]);
}

- (void)configureWithProviderType:(AIProviderType)type selected:(BOOL)selected configured:(BOOL)configured {
    id<AIProviderProtocol> provider = [[AIProviderFactory sharedFactory] createProviderOfType:type];

    // Icon & name
    self.nameLabel.text = provider.providerName;

    switch (type) {
        case AIProviderTypeOpenAI:
            self.iconImageView.image = [UIImage systemImageNamed:@"circle.hexagongrid.fill"];
            self.iconImageView.tintColor = [UIColor systemGreenColor];
            self.iconImageView.backgroundColor = [UIColor systemGreenColor].colorWithAlphaComponent(0.2);
            break;
        case AIProviderTypeAnthropic:
            self.iconImageView.image = [UIImage systemImageNamed:@"cpu.fill"];
            self.iconImageView.tintColor = [UIColor systemPurpleColor];
            self.iconImageView.backgroundColor = [UIColor systemPurpleColor].colorWithAlphaComponent(0.2);
            break;
        case AIProviderTypeGemini:
            self.iconImageView.image = [UIImage systemImageNamed:@"sparkles"];
            self.iconImageView.tintColor = [UIColor systemBlueColor];
            self.iconImageView.backgroundColor = [UIColor systemBlueColor].colorWithAlphaComponent(0.2);
            break;
        case AIProviderTypeCustom:
            self.iconImageView.image = [UIImage systemImageNamed:@"gearshape.fill"];
            self.iconImageView.tintColor = [UIColor systemOrangeColor];
            self.iconImageView.backgroundColor = [UIColor systemOrangeColor].colorWithAlphaComponent(0.2);
            break;
    }

    // Status
    if (configured) {
        self.statusLabel.text = @"API Key configured";
        self.statusLabel.textColor = [UIColor systemGreenColor];
    } else {
        self.statusLabel.text = @"Tap to add API key";
        self.statusLabel.textColor = [UIColor tertiaryLabel];
    }

    // Selection
    self.checkmarkImageView.image = selected ? [UIImage systemImageNamed:@"checkmark.circle.fill"] : [UIImage systemImageNamed:@"circle"];
    self.checkmarkImageView.tintColor = selected ? [UIColor systemBlueColor] : [UIColor tertiaryLabel];

    // Highlight if selected
    self.contentView.backgroundColor = selected ? [UIColor systemBlueColor].colorWithAlphaComponent(0.1) : [UIColor clearColor];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.iconImageView.image = nil;
    self.nameLabel.text = nil;
    self.statusLabel.text = nil;
    self.checkmarkImageView.image = nil;
}

@end