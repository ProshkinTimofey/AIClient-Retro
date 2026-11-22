//
//  AITerminalMessageView.m
//  AIClient
//
//  Theme-aware message cell with manual layout (no Auto Layout)
//

#import "AITerminalMessageView.h"
#import "AIAttachment.h"
#import "AIMessage.h"
#import "AITheme.h"

@interface AITerminalMessageView ()

@property (nonatomic, strong) UILabel *roleLabel;
@property (nonatomic, strong) UILabel *contentLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIView *attachmentsView;
@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, assign) BOOL isUser;
@property (nonatomic, assign) BOOL isStreaming;
@property (nonatomic, assign) CGFloat lastCalculatedHeight;
@property (nonatomic, assign) CGFloat lastWidth;

@end

@implementation AITerminalMessageView

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    // Bubble background view
    self.bubbleView = [[UIView alloc] initWithFrame:CGRectZero];
    self.bubbleView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentView addSubview:self.bubbleView];

    // Role prefix
    self.roleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.roleLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    self.roleLabel.numberOfLines = 1;
    [self.bubbleView addSubview:self.roleLabel];

    // Content
    self.contentLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.contentLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.contentLabel.numberOfLines = 0;
    self.contentLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self.bubbleView addSubview:self.contentLabel];

    // Time
    self.timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.timeLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    self.timeLabel.numberOfLines = 1;
    [self.bubbleView addSubview:self.timeLabel];

    // Attachments container
    self.attachmentsView = [[UIView alloc] initWithFrame:CGRectZero];
    self.attachmentsView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.bubbleView addSubview:self.attachmentsView];

    self.contentView.backgroundColor = [UIColor clearColor];
    self.backgroundColor = [UIColor clearColor];
}

- (void)configureWithMessage:(AIMessage *)message theme:(id<AITheme>)theme {
    _message = message;
    _isUser = message.role == AIMessageRoleUser;
    _isStreaming = message.status == AIMessageStatusStreaming;

    // Apply theme
    self.contentView.backgroundColor = [UIColor clearColor];
    self.backgroundColor = [UIColor clearColor];

    // Bubble styling
    self.bubbleView.backgroundColor = [theme bubbleColorForRole:message.role isOutgoing:_isUser];
    self.bubbleView.layer.cornerRadius = [theme bubbleCornerRadiusForRole:message.role isOutgoing:_isUser];
    self.bubbleView.layer.masksToBounds = YES;

    // Theme-specific styling
    if (theme.themeType == AIThemeTypeClaudeCode) {
        // ASCII-style border
        self.bubbleView.layer.borderWidth = 1.0;
        self.bubbleView.layer.borderColor = theme.borderColor.CGColor;
    }

    // Role label
    [theme styleLabel:self.roleLabel style:@"monospace"];
    self.roleLabel.text = _isUser ? @">>> You" : @"<<< AI";
    self.roleLabel.textColor = _isUser ? theme.primaryColor : theme.accentColor;

    // Content label
    [theme styleLabel:self.contentLabel style:@"monospace"];
    self.contentLabel.text = message.content.length > 0 ? message.content : @"[empty]";

    // Time label
    [theme styleLabel:self.timeLabel style:@"caption"];
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = @"HH:mm:ss";
    self.timeLabel.text = [f stringFromDate:message.timestamp];
    self.timeLabel.textColor = theme.textMutedColor;

    // Attachments
    [self.attachmentsView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    if (message.attachments.count > 0) {
        CGFloat yOffset = 0;
        CGFloat attWidth = CGRectGetWidth(self.bounds) - 48; // Will be recalculated in layoutSubviews

        for (AIAttachment *att in message.attachments) {
            UILabel *attLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, yOffset, attWidth, 18)];
            attLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [theme styleLabel:attLabel style:@"caption"];
            attLabel.backgroundColor = theme.surfaceColor;
            attLabel.layer.borderColor = theme.borderColor.CGColor;
            attLabel.layer.borderWidth = theme.borderWidth;
            attLabel.layer.cornerRadius = theme.useRoundedCorners ? 4 : 0;
            attLabel.clipsToBounds = YES;
            attLabel.textAlignment = NSTextAlignmentCenter;

            if (att.type == AIAttachmentTypeImage) {
                attLabel.text = [NSString stringWithFormat:@"[IMG] %@ (%@)", att.fileName, [self formatSize:att.fileSize]];
            } else {
                attLabel.text = [NSString stringWithFormat:@"[FILE] %@ (%@)", att.fileName, [self formatSize:att.fileSize]];
            }

            [self.attachmentsView addSubview:attLabel];
            yOffset += 22;
        }
        self.attachmentsView.frame = CGRectMake(0, 0, attWidth, yOffset);
    }

    self.attachmentsView.hidden = message.attachments.count == 0;

    // Trigger layout
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    id<AITheme> theme = [[AIThemeManager sharedManager] currentTheme];
    UIEdgeInsets insets = [theme bubbleInsetsForRole:_message.role isOutgoing:_isUser];
    CGFloat cornerRadius = [theme bubbleCornerRadiusForRole:_message.role isOutgoing:_isUser];

    CGRect bounds = self.contentView.bounds;
    CGFloat maxBubbleWidth = bounds.size.width - insets.left - insets.right - 24; // 24 = role label margin

    // Bubble frame
    CGFloat bubbleX = _isUser ? (bounds.size.width - maxBubbleWidth - insets.right) : insets.left;
    CGFloat bubbleY = insets.top;
    CGFloat bubbleWidth = maxBubbleWidth;

    // Calculate content height
    CGSize roleSize = [self.roleLabel sizeThatFits:CGSizeMake(bubbleWidth - 16, CGFLOAT_MAX)];
    CGSize contentSize = [self.contentLabel sizeThatFits:CGSizeMake(bubbleWidth - 16, CGFLOAT_MAX)];
    CGSize timeSize = [self.timeLabel sizeThatFits:CGSizeMake(bubbleWidth - 16, CGFLOAT_MAX)];
    CGSize attSize = self.attachmentsView.hidden ? CGSizeZero : self.attachmentsView.frame.size;

    CGFloat verticalPadding = 8;
    CGFloat bubbleHeight = verticalPadding * 2 + roleSize.height + 2 + contentSize.height + 6 + attSize.height + 4 + timeSize.height;

    self.bubbleView.frame = CGRectMake(bubbleX, bubbleY, bubbleWidth, bubbleHeight);
    self.bubbleView.layer.cornerRadius = cornerRadius;

    // Layout subviews inside bubble
    CGFloat x = 8;
    CGFloat y = verticalPadding;
    CGFloat w = bubbleWidth - 16;

    self.roleLabel.frame = CGRectMake(x, y, w, roleSize.height);
    y += roleSize.height + 2;

    self.contentLabel.frame = CGRectMake(x, y, w, contentSize.height);
    y += contentSize.height + 6;

    if (!self.attachmentsView.hidden) {
        self.attachmentsView.frame = CGRectMake(x, y, w, attSize.height);
        y += attSize.height + 4;
    } else {
        self.attachmentsView.frame = CGRectMake(x, y, w, 0);
    }

    self.timeLabel.frame = CGRectMake(bubbleWidth - timeSize.width - 8, y, timeSize.width, timeSize.height);

    // Cache height
    _lastCalculatedHeight = bubbleHeight + insets.top + insets.bottom;
    _lastWidth = bounds.size.width;
}

+ (CGFloat)heightForMessage:(AIMessage *)message theme:(id<AITheme>)theme width:(CGFloat)width {
    UIEdgeInsets insets = [theme bubbleInsetsForRole:message.role isOutgoing:message.role == AIMessageRoleUser];
    CGFloat maxBubbleWidth = width - insets.left - insets.right - 24;

    // Create temp labels for measurement
    UIFont *font = theme.fontMonospace;
    UIFont *captionFont = theme.fontCaption;

    NSString *roleText = (message.role == AIMessageRoleUser) ? @">>> You" : @"<<< AI";
    CGSize roleSize = [roleText boundingRectWithSize:CGSizeMake(maxBubbleWidth - 16, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:@{NSFontAttributeName: font}
                                             context:nil].size;

    CGSize contentSize = [message.content boundingRectWithSize:CGSizeMake(maxBubbleWidth - 16, CGFLOAT_MAX)
                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                  attributes:@{NSFontAttributeName: font}
                                                     context:nil].size;

    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = @"HH:mm:ss";
    NSString *timeText = [f stringFromDate:message.timestamp];
    CGSize timeSize = [timeText boundingRectWithSize:CGSizeMake(maxBubbleWidth - 16, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:@{NSFontAttributeName: captionFont}
                                             context:nil].size;

    CGFloat attHeight = 0;
    if (message.attachments.count > 0) {
        attHeight = message.attachments.count * 22;
    }

    CGFloat verticalPadding = 8;
    CGFloat bubbleHeight = verticalPadding * 2 + roleSize.height + 2 + contentSize.height + 6 + attHeight + 4 + timeSize.height;

    return bubbleHeight + insets.top + insets.bottom;
}

- (NSString *)formatSize:(unsigned long long)bytes {
    if (bytes < 1024) return [NSString stringWithFormat:@"%llu B", bytes];
    if (bytes < 1024*1024) return [NSString stringWithFormat:@"%.1f KB", (double)bytes/1024];
    return [NSString stringWithFormat:@"%.1f MB", (double)bytes/(1024*1024)];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.contentLabel.text = nil;
    self.timeLabel.text = nil;
    self.roleLabel.text = nil;
    [self.attachmentsView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.bubbleView.layer.borderWidth = 0;
    self.bubbleView.layer.borderColor = nil;
    _lastCalculatedHeight = 0;
    _lastWidth = 0;
}

@end