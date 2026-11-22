//
//  AITerminalStatusBar.m
//  AIClient
//
//  Theme-aware status bar with manual layout (no Auto Layout)
//

#import "AITerminalStatusBar.h"
#import "AITheme.h"

@implementation AITerminalStatusBar

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    // Provider label
    self.providerLabel = [self createLabel];
    self.providerLabel.font = [UIFont fontWithName:@"Courier" size:10];
    self.providerLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:self.providerLabel];

    // Model label
    self.modelLabel = [self createLabel];
    self.modelLabel.font = [UIFont fontWithName:@"Courier" size:10];
    self.modelLabel.textAlignment = NSTextAlignmentCenter;
    self.modelLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:self.modelLabel];

    // Count label
    self.countLabel = [self createLabel];
    self.countLabel.font = [UIFont fontWithName:@"Courier" size:10];
    self.countLabel.textAlignment = NSTextAlignmentRight;
    self.countLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:self.countLabel];

    // Default style (will be updated by theme)
    [self applyDefaultStyle];
}

- (UILabel *)createLabel {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.textColor = [UIColor greenColor];
    label.backgroundColor = [UIColor clearColor];
    label.shadowColor = [UIColor blackColor];
    label.shadowOffset = CGSizeMake(0, 1);
    return label;
}

- (void)applyDefaultStyle {
    self.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];
    self.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1.0].CGColor;
    self.layer.borderWidth = 0.5;

    self.providerLabel.textColor = [UIColor greenColor];
    self.modelLabel.textColor = [UIColor greenColor];
    self.countLabel.textColor = [UIColor greenColor];
}

- (void)applyTheme:(id<AITheme>)theme {
    self.backgroundColor = theme.surfaceColor;
    self.layer.borderColor = theme.borderColor.CGColor;
    self.layer.borderWidth = theme.borderWidth;

    [theme styleLabel:self.providerLabel style:@"monospace"];
    self.providerLabel.textColor = theme.primaryColor;

    [theme styleLabel:self.modelLabel style:@"monospace"];
    self.modelLabel.textColor = theme.primaryColor;

    [theme styleLabel:self.countLabel style:@"caption"];
    self.countLabel.textColor = theme.textMutedColor;

    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGRect bounds = self.bounds;
    CGFloat padding = 8;
    CGFloat labelHeight = 14;
    CGFloat labelY = (bounds.size.height - labelHeight) / 2;
    CGFloat thirdWidth = (bounds.size.width - padding * 2) / 3;

    self.providerLabel.frame = CGRectMake(padding, labelY, thirdWidth, labelHeight);
    self.modelLabel.frame = CGRectMake(padding + thirdWidth, labelY, thirdWidth, labelHeight);
    self.countLabel.frame = CGRectMake(bounds.size.width - padding - thirdWidth, labelY, thirdWidth, labelHeight);
}

@end