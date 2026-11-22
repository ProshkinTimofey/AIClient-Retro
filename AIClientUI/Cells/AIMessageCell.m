//
//  AIMessageCell.m
//  AIClient
//

#import "AIMessageCell.h"
#import "AIAttachment.h"
#import "AIImagePreviewView.h"

@interface AIMessageCell ()

@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, strong) UILabel *textLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIStackView *attachmentsStackView;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) NSLayoutConstraint *bubbleLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bubbleTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *avatarLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *avatarTrailingConstraint;
@property (nonatomic, assign) BOOL isUser;

@end

@implementation AIMessageCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = [UIColor clearColor];

    // Avatar
    self.avatarImageView = [[UIImageView alloc] init];
    self.avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarImageView.layer.cornerRadius = 16;
    self.avatarImageView.clipsToBounds = YES;
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.backgroundColor = [UIColor systemGray4Color];
    [self.contentView addSubview:self.avatarImageView];

    // Bubble
    self.bubbleView = [[UIView alloc] init];
    self.bubbleView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bubbleView.layer.cornerRadius = 18;
    self.bubbleView.layer.maskedCorners = kCALayerMaskedCorners;
    [self.contentView addSubview:self.bubbleView];

    // Text label
    self.textLabel = [[UILabel alloc] init];
    self.textLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.textLabel.numberOfLines = 0;
    self.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.textLabel.textColor = [UIColor label];
    [self.bubbleView addSubview:self.textLabel];

    // Time label
    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    self.timeLabel.textColor = [UIColor tertiaryLabel];
    [self.bubbleView addSubview:self.timeLabel];

    // Attachments stack
    self.attachmentsStackView = [[UIStackView alloc] init];
    self.attachmentsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.attachmentsStackView.axis = UILayoutConstraintAxisVertical;
    self.attachmentsStackView.spacing = 8;
    self.attachmentsStackView.distribution = UIStackViewDistributionFill;
    [self.bubbleView addSubview:self.attachmentsStackView];

    // Constraints
    self.bubbleLeadingConstraint = [self.bubbleView.leadingAnchor constraintEqualToAnchor:self.avatarImageView.trailingAnchor constant:8];
    self.bubbleTrailingConstraint = [self.bubbleView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16];

    self.avatarLeadingConstraint = [self.avatarImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12];
    self.avatarTrailingConstraint = [self.avatarImageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12];

    [NSLayoutConstraint activateConstraints:@[
        // Avatar
        self.avatarImageView.topAnchor.constraintEqualToAnchor:self.contentView.topAnchor constant:4,
        self.avatarImageView.widthAnchor.constraintEqualToConstant(32),
        self.avatarImageView.heightAnchor.constraintEqualToConstant(32),
        self.avatarImageView.bottomAnchor.constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-4,

        // Bubble
        self.bubbleView.topAnchor.constraintEqualToAnchor:self.contentView.topAnchor constant:4,
        self.bubbleView.bottomAnchor.constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4,
        self.bubbleView.widthAnchor.constraintLessThanOrEqualToAnchor:self.contentView.widthAnchor multiplier:0.75,

        // Text
        self.textLabel.topAnchor.constraintEqualToAnchor:self.bubbleView.topAnchor constant:12,
        self.textLabel.leadingAnchor.constraintEqualToAnchor:self.bubbleView.leadingAnchor constant:14,
        self.textLabel.trailingAnchor.constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-14,

        // Attachments
        self.attachmentsStackView.topAnchor.constraintEqualToAnchor:self.textLabel.bottomAnchor constant:8,
        self.attachmentsStackView.leadingAnchor.constraintEqualToAnchor:self.bubbleView.leadingAnchor constant:12,
        self.attachmentsStackView.trailingAnchor.constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-12,

        // Time
        self.timeLabel.topAnchor.constraintEqualToAnchor:self.attachmentsStackView.bottomAnchor constant:8,
        self.timeLabel.trailingAnchor.constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-12,
        self.timeLabel.bottomAnchor.constraintEqualToAnchor:self.bubbleView.bottomAnchor constant:-8,
    ]];
}

- (void)configureWithMessage:(AIMessage *)message {
    _message = message;
    _isUser = message.role == AIMessageRoleUser;

    // Update avatar
    if (_isUser) {
        self.avatarImageView.image = [UIImage systemImageNamed:@"person.circle.fill"];
        self.avatarImageView.tintColor = [UIColor systemBlueColor];
        self.bubbleView.backgroundColor = [UIColor systemBlueColor];
        self.textLabel.textColor = [UIColor whiteColor];
        self.timeLabel.textColor = [UIColor whiteColor].colorWithAlphaComponent(0.8);
    } else {
        self.avatarImageView.image = [UIImage systemImageNamed:@"cpu.fill"];
        self.avatarImageView.tintColor = [UIColor systemPurpleColor];
        self.bubbleView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        self.textLabel.textColor = [UIColor label];
        self.timeLabel.textColor = [UIColor tertiaryLabel];
    }

    // Update constraints for user/assistant layout
    if (_isUser) {
        self.bubbleLeadingConstraint.active = NO;
        self.bubbleTrailingConstraint.active = YES;
        self.avatarLeadingConstraint.active = NO;
        self.avatarTrailingConstraint.active = YES;
    } else {
        self.bubbleLeadingConstraint.active = YES;
        self.bubbleTrailingConstraint.active = NO;
        self.avatarLeadingConstraint.active = YES;
        self.avatarTrailingConstraint.active = NO;
    }

    // Text
    self.textLabel.text = message.content;
    self.textLabel.hidden = message.content.length == 0;

    // Time
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.timeStyle = NSDateFormatterShortStyle;
    self.timeLabel.text = [formatter stringFromDate:message.timestamp];

    // Attachments
    [self.attachmentsStackView.arrangedSubviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    for (AIAttachment *attachment in message.attachments) {
        if (attachment.type == AIAttachmentTypeImage) {
            AIImagePreviewView *preview = [[AIImagePreviewView alloc] initWithAttachment:attachment];
            [self.attachmentsStackView addArrangedSubview:preview];
        } else {
            // File attachment
            UILabel *fileLabel = [[UILabel alloc] init];
            fileLabel.text = [NSString stringWithFormat:@"📄 %@", attachment.fileName];
            fileLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
            fileLabel.textColor = _isUser ? [UIColor whiteColor] : [UIColor secondaryLabel];
            [self.attachmentsStackView addArrangedSubview:fileLabel];
        }
    }

    self.attachmentsStackView.hidden = message.attachments.count == 0;

    [self setNeedsLayout];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.textLabel.text = nil;
    self.timeLabel.text = nil;
    [self.attachmentsStackView.arrangedSubviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
}

@end