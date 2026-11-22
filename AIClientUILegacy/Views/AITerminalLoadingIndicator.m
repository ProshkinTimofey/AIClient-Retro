//
//  AITerminalLoadingIndicator.m
//  AIClient
//
//  Theme-aware loading indicator with manual layout (no Auto Layout)
//

#import "AITerminalLoadingIndicator.h"
#import "AITheme.h"

@interface AITerminalLoadingIndicator ()

@property (nonatomic, strong) UILabel *dotsLabel;
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic, assign) NSInteger frame;
@property (nonatomic, assign) BOOL isFirstLayout;

@end

@implementation AITerminalLoadingIndicator

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _isFirstLayout = YES;
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

    self.dotsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.dotsLabel.font = [UIFont fontWithName:@"Courier-Bold" size:18];
    self.dotsLabel.textAlignment = NSTextAlignmentCenter;
    self.dotsLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:self.dotsLabel];

    // Default style (will be updated by theme)
    [self applyDefaultStyle];

    // Fixed size - centered in parent
    self.frame = CGRectMake(0, 0, 120, 60);
}

- (void)applyDefaultStyle {
    self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    self.layer.cornerRadius = 8;
    self.layer.borderColor = [UIColor greenColor].CGColor;
    self.layer.borderWidth = 1;

    self.dotsLabel.textColor = [UIColor greenColor];
}

- (void)applyTheme:(id<AITheme>)theme {
    self.backgroundColor = [theme.surfaceColor colorWithAlphaComponent:0.95];
    self.layer.cornerRadius = theme.useRoundedCorners ? 8 : 0;
    self.layer.borderColor = theme.borderColor.CGColor;
    self.layer.borderWidth = theme.borderWidth;

    [theme styleLabel:self.dotsLabel style:@"monospace"];
    self.dotsLabel.textColor = theme.primaryColor;

    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    if (_isFirstLayout) {
        _isFirstLayout = NO;
    }

    // Center dots label
    self.dotsLabel.frame = self.bounds;
}

- (void)startAnimating {
    self.hidden = NO;
    _frame = 0;
    self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
    [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopAnimating {
    self.hidden = YES;
    [self.link invalidate];
    self.link = nil;
    self.dotsLabel.text = @"";
}

- (void)tick {
    _frame = (_frame + 1) % 20;
    NSInteger dots = (_frame / 5) + 1;
    self.dotsLabel.text = [NSString stringWithFormat:@"[%@]", [@"..." substringToIndex:dots]];
}

@end