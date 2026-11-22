//
//  AITerminalConversationCell.m
//  AIClient
//
//  Theme-aware conversation cell with manual layout (no Auto Layout)
//

#import "AITerminalConversationCell.h"
#import "AIConversation.h"
#import "AIMessage.h"
#import "AITheme.h"

@interface AITerminalConversationCell ()

@property (nonatomic, strong) UILabel *indexLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *previewLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *modelLabel;
@property (nonatomic, strong) UIView *selectionBackground;
@property (nonatomic, strong) UIView *separator;

@end

@implementation AITerminalConversationCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.backgroundColor = [UIColor blackColor];
    self.contentView.backgroundColor = [UIColor blackColor];

    // Custom selection background
    self.selectionBackground = [[UIView alloc] init];
    self.selectedBackgroundView = self.selectionBackground;

    // Index number (like terminal line numbers)
    self.indexLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.indexLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.indexLabel.font = [UIFont fontWithName:@"Courier" size:11];
    self.indexLabel.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:self.indexLabel];

    // Title
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    self.titleLabel.font = [UIFont fontWithName:@"Courier-Bold" size:13];
    [self.contentView addSubview:self.titleLabel];

    // Preview (last message)
    self.previewLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.previewLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.previewLabel.font = [UIFont fontWithName:@"Courier" size:11];
    self.previewLabel.numberOfLines = 2;
    [self.contentView addSubview:self.previewLabel];

    // Time
    self.timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.timeLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.timeLabel.font = [UIFont fontWithName:@"Courier" size:10];
    self.timeLabel.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:self.timeLabel];

    // Model badge
    self.modelLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.modelLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.modelLabel.font = [UIFont fontWithName:@"Courier" size:9];
    self.modelLabel.textAlignment = NSTextAlignmentRight;
    self.modelLabel.layer.cornerRadius = 3;
    self.modelLabel.clipsToBounds = YES;
    [self.contentView addSubview:self.modelLabel];

    // Separator line
    self.separator = [[UIView alloc] initWithFrame:CGRectZero];
    self.separator.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.contentView addSubview:self.separator];

    // Default style
    [self applyDefaultStyle];
}

- (void)applyDefaultStyle {
    self.backgroundColor = [UIColor blackColor];
    self.contentView.backgroundColor = [UIColor blackColor];

    self.selectionBackground.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];

    self.indexLabel.textColor = [UIColor colorWithWhite:0.4 alpha:1.0];
    self.titleLabel.textColor = [UIColor greenColor];
    self.previewLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.timeLabel.textColor = [UIColor colorWithWhite:0.4 alpha:1.0];
    self.modelLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    self.modelLabel.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1.0].CGColor;
    self.modelLabel.layer.borderWidth = 0.5;

    self.separator.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
}

- (void)applyTheme:(id<AITheme>)theme {
    self.backgroundColor = theme.backgroundColor;
    self.contentView.backgroundColor = theme.backgroundColor;

    self.selectionBackground.backgroundColor = [theme.surfaceColor colorWithAlphaComponent:0.5];

    [theme styleLabel:self.indexLabel style:@"caption"];
    self.indexLabel.textColor = theme.textMutedColor;

    [theme styleLabel:self.titleLabel style:@"monospace"];
    self.titleLabel.textColor = theme.primaryColor;

    [theme styleLabel:self.previewLabel style:@"monospace"];
    self.previewLabel.textColor = theme.textSecondaryColor;

    [theme styleLabel:self.timeLabel style:@"caption"];
    self.timeLabel.textColor = theme.textMutedColor;

    [theme styleLabel:self.modelLabel style:@"caption"];
    self.modelLabel.textColor = theme.textMutedColor;
    self.modelLabel.layer.borderColor = theme.borderColor.CGColor;
    self.modelLabel.layer.borderWidth = theme.borderWidth;
    self.modelLabel.layer.cornerRadius = theme.useRoundedCorners ? 3 : 0;

    self.separator.backgroundColor = theme.separatorColor;

    [self setNeedsLayout];
}

- (void)configureWithConversation:(AIConversation *)conversation index:(NSUInteger)index theme:(id<AITheme>)theme {
    // Index (1-based like terminal lines)
    self.indexLabel.text = [NSString stringWithFormat:@"%02lu", (unsigned long)index + 1];

    self.titleLabel.text = conversation.title ?: @"Untitled";

    AIMessage *lastMsg = conversation.lastMessage;
    if (lastMsg) {
        NSString *preview = lastMsg.content;
        if (preview.length > 60) preview = [preview substringToIndex:60];
        self.previewLabel.text = [NSString stringWithFormat:@"%@: %@",
            lastMsg.role == AIMessageRoleUser ? @"> You" : @"< AI", preview];

        // Time
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm";
        self.timeLabel.text = [formatter stringFromDate:lastMsg.timestamp];
    } else {
        self.previewLabel.text = @"[Empty conversation]";
        self.timeLabel.text = @"--:--";
    }

    // Model badge
    self.modelLabel.text = conversation.model ? [NSString stringWithFormat:@" %@ ", conversation.model] : @"";
    self.modelLabel.hidden = !conversation.model;

    // Apply theme
    [self applyTheme:theme];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGRect bounds = self.contentView.bounds;
    CGFloat padding = 8;
    CGFloat indexWidth = 30;
    CGFloat timeWidth = 50;
    CGFloat modelWidth = 70;
    CGFloat modelHeight = 16;
    CGFloat topPadding = 6;
    CGFloat bottomPadding = 6;

    // Index label - left
    self.indexLabel.frame = CGRectMake(padding, topPadding, indexWidth, 14);

    // Time label - top right
    self.timeLabel.frame = CGRectMake(bounds.size.width - padding - timeWidth, topPadding, timeWidth, 12);

    // Model badge - below time
    self.modelLabel.frame = CGRectMake(bounds.size.width - padding - modelWidth, topPadding + 14, modelWidth, modelHeight);

    // Title - next to index, before model
    CGFloat titleX = padding + indexWidth + 8;
    CGFloat titleMaxWidth = bounds.size.width - titleX - padding - modelWidth - 8;
    self.titleLabel.frame = CGRectMake(titleX, topPadding, titleMaxWidth, 16);

    // Preview - below title, full width minus padding
    CGFloat previewY = topPadding + 16 + 2;
    CGFloat previewHeight = bounds.size.height - previewY - bottomPadding;
    self.previewLabel.frame = CGRectMake(titleX, previewY, bounds.size.width - titleX - padding, previewHeight);

    // Separator at bottom
    self.separator.frame = CGRectMake(0, bounds.size.height - 0.5, bounds.size.width, 0.5);
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.titleLabel.text = nil;
    self.previewLabel.text = nil;
    self.timeLabel.text = nil;
    self.modelLabel.text = nil;
    self.indexLabel.text = nil;
    self.modelLabel.hidden = NO;
}

@end