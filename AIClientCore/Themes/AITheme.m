//
//  AITheme.m
//  AIClient
//

#import "AITheme.h"
#import "AIMessage.h"

// Theme keys
NSString *const AIThemeColorBackground = @"background";
NSString *const AIThemeColorSurface = @"surface";
NSString *const AIThemeColorPrimary = @"primary";
NSString *const AIThemeColorSecondary = @"secondary";
NSString *const AIThemeColorAccent = @"accent";
NSString *const AIThemeColorTextPrimary = @"textPrimary";
NSString *const AIThemeColorTextSecondary = @"textSecondary";
NSString *const AIThemeColorTextMuted = @"textMuted";
NSString *const AIThemeColorSeparator = @"separator";
NSString *const AIThemeColorBorder = @"border";
NSString *const AIThemeColorInputBackground = @"inputBackground";
NSString *const AIThemeColorInputBorder = @"inputBorder";
NSString *const AIThemeColorButtonBackground = @"buttonBackground";
NSString *const AIThemeColorButtonText = @"buttonText";
NSString *const AIThemeColorNavigationBar = @"navigationBar";
NSString *const AIThemeColorNavigationBarText = @"navigationBarText";
NSString *const AIThemeColorUserMessage = @"userMessage";
NSString *const AIThemeColorAssistantMessage = @"assistantMessage";
NSString *const AIThemeColorSystemMessage = @"systemMessage";
NSString *const AIThemeColorStreamingIndicator = @"streamingIndicator";

NSString *const AIThemeFontRegular = @"regular";
NSString *const AIThemeFontMedium = @"medium";
NSString *const AIThemeFontBold = @"bold";
NSString *const AIThemeFontMonospace = @"monospace";
NSString *const AIThemeFontMonospaceSmall = @"monospaceSmall";
NSString *const AIThemeFontTitle = @"title";
NSString *const AIThemeFontCaption = @"caption";

#pragma mark - Base Theme Implementation

@interface AIBaseTheme : NSObject <AITheme>
@property (nonatomic, readonly) AIThemeType themeType;
@property (nonatomic, readonly, copy) NSString *displayName;

@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, strong) UIColor *surfaceColor;
@property (nonatomic, strong) UIColor *primaryColor;
@property (nonatomic, strong) UIColor *secondaryColor;
@property (nonatomic, strong) UIColor *accentColor;
@property (nonatomic, strong) UIColor *textPrimaryColor;
@property (nonatomic, strong) UIColor *textSecondaryColor;
@property (nonatomic, strong) UIColor *textMutedColor;
@property (nonatomic, strong) UIColor *separatorColor;
@property (nonatomic, strong) UIColor *borderColor;
@property (nonatomic, strong) UIColor *inputBackgroundColor;
@property (nonatomic, strong) UIColor *inputBorderColor;
@property (nonatomic, strong) UIColor *buttonBackgroundColor;
@property (nonatomic, strong) UIColor *buttonTextColor;
@property (nonatomic, strong) UIColor *navigationBarColor;
@property (nonatomic, strong) UIColor *navigationBarTextColor;
@property (nonatomic, strong) UIColor *statusBarStyle;
@property (nonatomic, strong) UIColor *userMessageColor;
@property (nonatomic, strong) UIColor *assistantMessageColor;
@property (nonatomic, strong) UIColor *systemMessageColor;
@property (nonatomic, strong) UIColor *streamingIndicatorColor;

@property (nonatomic, strong) UIFont *fontRegular;
@property (nonatomic, strong) UIFont *fontMedium;
@property (nonatomic, strong) UIFont *fontBold;
@property (nonatomic, strong) UIFont *fontMonospace;
@property (nonatomic, strong) UIFont *fontMonospaceSmall;
@property (nonatomic, strong) UIFont *fontTitle;
@property (nonatomic, strong) UIFont *fontCaption;

@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) CGFloat borderWidth;
@property (nonatomic, assign) CGFloat buttonHeight;
@property (nonatomic, assign) CGFloat inputHeight;
@property (nonatomic, assign) CGFloat cellPadding;
@property (nonatomic, assign) CGFloat navigationBarHeight;
@property (nonatomic, assign) CGFloat statusBarHeight;

@property (nonatomic, assign) CGSize shadowOffset;
@property (nonatomic, assign) CGFloat shadowRadius;
@property (nonatomic, assign) CGFloat shadowOpacity;
@property (nonatomic, assign) BOOL useGradients;
@property (nonatomic, assign) BOOL useTextures;
@property (nonatomic, assign) BOOL useRoundedCorners;

@property (nonatomic, strong) UIImage *backgroundTextureImage;
@property (nonatomic, strong) UIImage *navigationBarTextureImage;
@property (nonatomic, strong) NSMutableDictionary *buttonTextures;
@end

@implementation AIBaseTheme

- (instancetype)init {
    self = [super init];
    if (self) {
        _buttonTextures = [NSMutableDictionary dictionary];
        _useRoundedCorners = YES;
    }
    return self;
}

- (UIImage *)backgroundTexture {
    return _backgroundTextureImage;
}

- (UIImage *)navigationBarTexture {
    return _navigationBarTextureImage;
}

- (UIImage *)buttonTextureForState:(UIControlState)state {
    return _buttonTextures[@(state)];
}

- (UIImage *)cellBackgroundTexture {
    return nil;
}

#pragma mark - Component Styling (Base implementations)

- (void)styleNavigationBar:(UINavigationBar *)navBar {
    navBar.barTintColor = self.navigationBarColor;
    navBar.tintColor = self.navigationBarTextColor;
    navBar.titleTextAttributes = @{
        NSFontAttributeName: self.fontTitle,
        NSForegroundColorAttributeName: self.navigationBarTextColor
    };
    if (self.useTextures && self.navigationBarTextureImage) {
        [navBar setBackgroundImage:self.navigationBarTextureImage forBarMetrics:UIBarMetricsDefault];
    } else {
        [navBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    }
    navBar.translucent = NO;
}

- (void)styleToolbar:(UIToolbar *)toolbar {
    toolbar.barTintColor = self.navigationBarColor;
    toolbar.tintColor = self.navigationBarTextColor;
    if (self.useTextures && self.navigationBarTextureImage) {
        [toolbar setBackgroundImage:self.navigationBarTextureImage forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    }
    toolbar.translucent = NO;
}

- (void)styleTableView:(UITableView *)tableView {
    tableView.backgroundColor = self.backgroundColor;
    tableView.separatorColor = self.separatorColor;
    tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
}

- (void)styleTableViewCell:(UITableViewCell *)cell {
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    cell.selectedBackgroundView = [[UIView alloc] init];
    cell.selectedBackgroundView.backgroundColor = [self.primaryColor colorWithAlphaComponent:0.1];
}

- (void)styleTextView:(UITextView *)textView {
    textView.backgroundColor = self.inputBackgroundColor;
    textView.textColor = self.textPrimaryColor;
    textView.font = self.fontRegular;
    textView.layer.borderColor = self.inputBorderColor.CGColor;
    textView.layer.borderWidth = self.borderWidth;
    textView.layer.cornerRadius = self.cornerRadius;
    textView.clipsToBounds = YES;
    textView.tintColor = self.accentColor;
}

- (void)styleTextField:(UITextField *)textField {
    textField.backgroundColor = self.inputBackgroundColor;
    textField.textColor = self.textPrimaryColor;
    textField.font = self.fontRegular;
    textField.layer.borderColor = self.inputBorderColor.CGColor;
    textField.layer.borderWidth = self.borderWidth;
    textField.layer.cornerRadius = self.cornerRadius;
    textField.clipsToBounds = YES;
    textField.tintColor = self.accentColor;

    NSDictionary *placeholderAttrs = @{
        NSForegroundColorAttributeName: self.textMutedColor,
        NSFontAttributeName: self.fontRegular
    };
    textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:textField.placeholder ?: @""
                                                                      attributes:placeholderAttrs];
}

- (void)styleButton:(UIButton *)button forState:(UIControlState)state {
    [button setTitleColor:self.buttonTextColor forState:UIControlStateNormal];
    [button setTitleColor:[self.buttonTextColor colorWithAlphaComponent:0.6] forState:UIControlStateHighlighted];
    [button setTitleColor:[self.buttonTextColor colorWithAlphaComponent:0.4] forState:UIControlStateDisabled];
    button.titleLabel.font = self.fontMedium;
    button.backgroundColor = self.buttonBackgroundColor;
    button.layer.cornerRadius = self.cornerRadius;
    button.clipsToBounds = YES;

    if (self.useTextures) {
        UIImage *tex = [self buttonTextureForState:state];
        if (tex) [button setBackgroundImage:tex forState:state];
    }
}

- (void)styleLabel:(UILabel *)label style:(NSString *)style {
    if ([style isEqualToString:@"title"]) {
        label.font = self.fontTitle;
        label.textColor = self.textPrimaryColor;
    } else if ([style isEqualToString:@"body"]) {
        label.font = self.fontRegular;
        label.textColor = self.textPrimaryColor;
    } else if ([style isEqualToString:@"caption"]) {
        label.font = self.fontCaption;
        label.textColor = self.textMutedColor;
    } else if ([style isEqualToString:@"monospace"]) {
        label.font = self.fontMonospace;
        label.textColor = self.textPrimaryColor;
    } else if ([style isEqualToString:@"secondary"]) {
        label.font = self.fontRegular;
        label.textColor = self.textSecondaryColor;
    }
}

- (void)styleSegmentedControl:(UISegmentedControl *)control {
    [control setBackgroundImage:[self segmentedBackgroundImage] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [control setBackgroundImage:[self segmentedSelectedImage] forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
    [control setDividerImage:[self segmentedDividerImage] forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];

    NSDictionary *normalAttrs = @{
        NSFontAttributeName: self.fontMedium,
        NSForegroundColorAttributeName: self.textSecondaryColor
    };
    NSDictionary *selectedAttrs = @{
        NSFontAttributeName: self.fontMedium,
        NSForegroundColorAttributeName: self.navigationBarTextColor
    };
    [control setTitleTextAttributes:normalAttrs forState:UIControlStateNormal];
    [control setTitleTextAttributes:selectedAttrs forState:UIControlStateSelected];
    control.tintColor = self.accentColor;
}

- (UIImage *)segmentedBackgroundImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 30), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, self.surfaceColor.CGColor);
    CGContextFillRect(ctx, CGContextGetClipBoundingBox(ctx));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(0, 5, 0, 5)];
}

- (UIImage *)segmentedSelectedImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 30), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, self.primaryColor.CGColor);
    CGContextFillRect(ctx, CGContextGetClipBoundingBox(ctx));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(0, 5, 0, 5)];
}

- (UIImage *)segmentedDividerImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 30), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, self.borderColor.CGColor);
    CGContextMoveToPoint(ctx, 0, 5);
    CGContextAddLineToPoint(ctx, 0, 25);
    CGContextStrokePath(ctx);
    return UIGraphicsGetImageFromCurrentImageContext();
}

- (void)styleSwitch:(UISwitch *)switchControl {
    switchControl.onTintColor = self.primaryColor;
    switchControl.tintColor = self.borderColor;
    switchControl.thumbTintColor = [UIColor whiteColor];
}

- (void)styleSlider:(UISlider *)slider {
    slider.minimumTrackTintColor = self.primaryColor;
    slider.maximumTrackTintColor = self.borderColor;
    slider.thumbTintColor = self.primaryColor;
}

- (void)styleProgressView:(UIProgressView *)progressView {
    progressView.progressTintColor = self.primaryColor;
    progressView.trackTintColor = self.borderColor;
}

- (void)styleActivityIndicator:(UIActivityIndicatorView *)indicator {
    indicator.color = self.accentColor;
}

- (void)styleAlertView:(UIAlertView *)alertView {
    // Base implementation - subclasses override
}

- (void)styleActionSheet:(UIActionSheet *)actionSheet {
    // Base implementation - subclasses override
}

- (void)styleBarButton:(UIBarButtonItem *)barButton withTheme:(id<AITheme>)theme {
    barButton.tintColor = theme.navigationBarTextColor;
    [barButton setTitleTextAttributes:@{
        NSFontAttributeName: theme.fontMonospaceSmall,
        NSForegroundColorAttributeName: theme.navigationBarTextColor
    } forState:UIControlStateNormal];
}

#pragma mark - Message Bubbles

- (UIColor *)bubbleColorForRole:(AIMessageRole)role isOutgoing:(BOOL)outgoing {
    if (outgoing) return self.userMessageColor;
    switch (role) {
        case AIMessageRoleAssistant: return self.assistantMessageColor;
        case AIMessageRoleSystem: return self.systemMessageColor;
        default: return self.surfaceColor;
    }
}

- (UIEdgeInsets)bubbleInsetsForRole:(AIMessageRole)role isOutgoing:(BOOL)outgoing {
    return UIEdgeInsetsMake(10, 14, 10, 14);
}

- (CGFloat)bubbleCornerRadiusForRole:(AIMessageRole)role isOutgoing:(BOOL)outgoing {
    return self.cornerRadius;
}

- (BOOL)shouldShowTailForRole:(AIMessageRole)role isOutgoing:(BOOL)outgoing {
    return YES;
}

@end

#pragma mark - Skeuomorphic Theme (iOS 6 Style)

@interface AISkeuomorphicTheme : AIBaseTheme
@end

@implementation AISkeuomorphicTheme

- (instancetype)init {
    self = [super init];
    if (self) {
        _themeType = AIThemeTypeSkeuomorphic;
        _displayName = @"Skeuomorphic (iOS 6)";

        // Colors - warm, textured feel
        _backgroundColor = [UIColor colorWithPatternImage:[self leatherTexture]];
        _surfaceColor = [UIColor colorWithWhite:0.95 alpha:1.0];
        _primaryColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0]; // iOS 6 blue
        _secondaryColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        _accentColor = [UIColor colorWithRed:1.0 green:0.6 blue:0.0 alpha:1.0]; // Orange accent
        _textPrimaryColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        _textSecondaryColor = [UIColor colorWithWhite:0.35 alpha:1.0];
        _textMutedColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        _separatorColor = [UIColor colorWithWhite:0.75 alpha:1.0];
        _borderColor = [UIColor colorWithWhite:0.7 alpha:1.0];
        _inputBackgroundColor = [UIColor whiteColor];
        _inputBorderColor = [UIColor colorWithWhite:0.7 alpha:1.0];
        _buttonBackgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
        _buttonTextColor = [UIColor whiteColor];
        _navigationBarColor = [UIColor colorWithPatternImage:[self metalTexture]];
        _navigationBarTextColor = [UIColor whiteColor];
        _statusBarStyle = (id)[UIColor whiteColor]; // Will be interpreted as UIStatusBarStyleLightContent
        _userMessageColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
        _assistantMessageColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        _systemMessageColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0];
        _streamingIndicatorColor = [UIColor colorWithRed:1.0 green:0.6 blue:0.0 alpha:1.0];

        // Fonts - iOS 6 used Helvetica Neue
        _fontRegular = [UIFont fontWithName:@"HelveticaNeue" size:16];
        _fontMedium = [UIFont fontWithName:@"HelveticaNeue-Medium" size:16];
        _fontBold = [UIFont fontWithName:@"HelveticaNeue-Bold" size:16];
        _fontMonospace = [UIFont fontWithName:@"Courier" size:14];
        _fontMonospaceSmall = [UIFont fontWithName:@"Courier" size:12];
        _fontTitle = [UIFont fontWithName:@"HelveticaNeue-Bold" size:18];
        _fontCaption = [UIFont fontWithName:@"HelveticaNeue" size:12];

        // Metrics
        _cornerRadius = 10.0;
        _borderWidth = 1.0;
        _buttonHeight = 44.0;
        _inputHeight = 44.0;
        _cellPadding = 12.0;
        _navigationBarHeight = 44.0;
        _statusBarHeight = 20.0;

        // Shadows - pronounced for depth
        _shadowOffset = CGSizeMake(0, 2);
        _shadowRadius = 4.0;
        _shadowOpacity = 0.3;
        _useGradients = YES;
        _useTextures = YES;
        _useRoundedCorners = YES;

        // Load textures
        _backgroundTextureImage = [self leatherTexture];
        _navigationBarTextureImage = [self metalTexture];
    }
    return self;
}

- (UIImage *)leatherTexture {
    // Generate leather-like texture programmatically
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(64, 64), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    // Base color
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0.92 green:0.88 blue:0.82 alpha:1.0].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, 64, 64));

    // Add noise/grain
    for (int i = 0; i < 1000; i++) {
        CGFloat x = arc4random_uniform(64);
        CGFloat y = arc4random_uniform(64);
        CGFloat alpha = (arc4random_uniform(100) / 1000.0) * 0.05;
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.0 alpha:alpha].CGColor);
        CGContextFillRect(ctx, CGRectMake(x, y, 1, 1));
    }

    // Add subtle leather grain lines
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.0 alpha:0.02].CGColor);
    CGContextSetLineWidth(ctx, 0.5);
    for (int i = 0; i < 20; i++) {
        CGFloat y = arc4random_uniform(64);
        CGContextMoveToPoint(ctx, 0, y);
        CGContextAddLineToPoint(ctx, 64, y + (arc4random_uniform(4) - 2));
        CGContextStrokePath(ctx);
    }

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)metalTexture {
    // Brushed metal texture for nav bars
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(64, 64), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.7 alpha:1.0].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, 64, 64));

    // Horizontal brush lines
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.6 alpha:1.0].CGColor);
    CGContextSetLineWidth(ctx, 0.5);
    for (int y = 0; y < 64; y += 2) {
        CGContextMoveToPoint(ctx, 0, y);
        CGContextAddLineToPoint(ctx, 64, y);
        CGContextStrokePath(ctx);
    }

    // Highlights
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.85 alpha:1.0].CGColor);
    for (int y = 1; y < 64; y += 4) {
        CGContextMoveToPoint(ctx, 0, y);
        CGContextAddLineToPoint(ctx, 64, y);
        CGContextStrokePath(ctx);
    }

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)buttonTextureForState:(UIControlState)state {
    NSString *key = [NSString stringWithFormat:@"button_%lu", (unsigned long)state];
    UIImage *cached = _buttonTextures[key];
    if (cached) return cached;

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(64, 44), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    UIColor *baseColor = (state & UIControlStateHighlighted) ?
        [self.primaryColor colorWithAlphaComponent:0.8] : self.primaryColor;
    UIColor *topColor = (state & UIControlStateHighlighted) ?
        [UIColor colorWithWhite:0.3 alpha:1.0] : [UIColor colorWithWhite:0.6 alpha:1.0];

    // Gradient background
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat colors[] = {
        CGColorGetComponents(topColor.CGColor)[0], CGColorGetComponents(topColor.CGColor)[1], CGColorGetComponents(topColor.CGColor)[2], CGColorGetComponents(topColor.CGColor)[3],
        CGColorGetComponents(baseColor.CGColor)[0], CGColorGetComponents(baseColor.CGColor)[1], CGColorGetComponents(baseColor.CGColor)[2], CGColorGetComponents(baseColor.CGColor)[3]
    };
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, colors, NULL, 2);
    CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, 0), CGPointMake(0, 44), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);

    // Glossy highlight
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.15].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, 64, 20));

    // Border
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.2 alpha:1.0].CGColor);
    CGContextSetLineWidth(ctx, 1.0);
    CGContextStrokeRect(ctx, CGRectInset(CGRectMake(0, 0, 64, 44), 0.5, 0.5));

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    _buttonTextures[key] = img;
    return img;
}

- (void)styleTableViewCell:(UITableViewCell *)cell {
    [super styleTableViewCell:cell];
    // Add subtle gradient background for cells
    cell.backgroundView = [[UIImageView alloc] initWithImage:[self cellBackgroundTexture]];
}

- (UIImage *)cellBackgroundTexture {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(64, 44), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.98 alpha:1.0].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, 64, 44));

    // Subtle bottom line
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.8 alpha:1.0].CGColor);
    CGContextSetLineWidth(ctx, 0.5);
    CGContextMoveToPoint(ctx, 0, 44);
    CGContextAddLineToPoint(ctx, 64, 44);
    CGContextStrokePath(ctx);

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
}

- (void)styleAlertView:(UIAlertView *)alertView {
    alertView.tintColor = self.primaryColor;
}

- (void)styleActionSheet:(UIActionSheet *)actionSheet {
    actionSheet.tintColor = self.primaryColor;
}

- (void)styleBarButton:(UIBarButtonItem *)barButton withTheme:(id<AITheme>)theme {
    [super styleBarButton:barButton withTheme:theme];
    barButton.tintColor = self.navigationBarTextColor;
}

@end

#pragma mark - Minimalist Theme (iOS 13+ Style)

@interface AIMinimalistTheme : AIBaseTheme
@end

@implementation AIMinimalistTheme

- (instancetype)init {
    self = [super init];
    if (self) {
        _themeType = AIThemeTypeMinimalist;
        _displayName = @"Minimalist (iOS 13+)";

        // Colors - system adaptive, clean
        _backgroundColor = [UIColor systemBackgroundColor];
        _surfaceColor = [UIColor secondarySystemBackgroundColor];
        _primaryColor = [UIColor systemBlueColor];
        _secondaryColor = [UIColor tertiarySystemBackgroundColor];
        _accentColor = [UIColor systemOrangeColor];
        _textPrimaryColor = [UIColor labelColor];
        _textSecondaryColor = [UIColor secondaryLabelColor];
        _textMutedColor = [UIColor tertiaryLabelColor];
        _separatorColor = [UIColor separatorColor];
        _borderColor = [UIColor colorWithWhite:0.0 alpha:0.1];
        _inputBackgroundColor = [UIColor tertiarySystemBackgroundColor];
        _inputBorderColor = [UIColor separatorColor];
        _buttonBackgroundColor = [UIColor systemBlueColor];
        _buttonTextColor = [UIColor whiteColor];
        _navigationBarColor = [UIColor systemBackgroundColor];
        _navigationBarTextColor = [UIColor labelColor];
        _statusBarStyle = (id)[UIColor blackColor]; // Will be interpreted as UIStatusBarStyleDefault
        _userMessageColor = [UIColor systemBlueColor];
        _assistantMessageColor = [UIColor secondarySystemBackgroundColor];
        _systemMessageColor = [UIColor systemYellowColor];
        _streamingIndicatorColor = [UIColor systemOrangeColor];

        // Fonts - San Francisco
        _fontRegular = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
        _fontMedium = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        _fontBold = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        _fontMonospace = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
        _fontMonospaceSmall = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
        _fontTitle = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
        _fontCaption = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];

        // Metrics - cleaner, more space
        _cornerRadius = 12.0;
        _borderWidth = 0.5;
        _buttonHeight = 48.0;
        _inputHeight = 48.0;
        _cellPadding = 16.0;
        _navigationBarHeight = 44.0;
        _statusBarHeight = 20.0;

        // Shadows - subtle
        _shadowOffset = CGSizeMake(0, 1);
        _shadowRadius = 2.0;
        _shadowOpacity = 0.1;
        _useGradients = NO;
        _useTextures = NO;
        _useRoundedCorners = YES;
    }
    return self;
}

- (void)styleNavigationBar:(UINavigationBar *)navBar {
    // iOS 13+ standard appearance
    navBar.barTintColor = self.navigationBarColor;
    navBar.tintColor = self.primaryColor;
    navBar.titleTextAttributes = @{
        NSFontAttributeName: self.fontTitle,
        NSForegroundColorAttributeName: self.textPrimaryColor
    };
    navBar.translucent = YES;
    navBar.shadowImage = [UIImage new]; // Remove hairline
}

- (void)styleButton:(UIButton *)button forState:(UIControlState)state {
    [super styleButton:button forState:state];
    // iOS 13+ style: no gradient, just solid color
    button.layer.shadowOffset = self.shadowOffset;
    button.layer.shadowRadius = self.shadowRadius;
    button.layer.shadowOpacity = self.shadowOpacity;
    button.layer.shadowColor = [UIColor blackColor].CGColor;
}

- (void)styleTextView:(UITextView *)textView {
    [super styleTextView:textView];
    textView.layer.shadowOffset = CGSizeZero;
    textView.layer.shadowRadius = 0;
    textView.layer.shadowOpacity = 0;
}

- (void)styleAlertView:(UIAlertView *)alertView {
    alertView.tintColor = self.primaryColor;
}

- (void)styleActionSheet:(UIActionSheet *)actionSheet {
    actionSheet.tintColor = self.primaryColor;
}

- (void)styleBarButton:(UIBarButtonItem *)barButton withTheme:(id<AITheme>)theme {
    [super styleBarButton:barButton withTheme:theme];
    barButton.tintColor = self.navigationBarTextColor;
}

@end

#pragma mark - Claude Code Theme (Terminal/Monospace)

@interface AIClaudeCodeTheme : AIBaseTheme
@end

@implementation AIClaudeCodeTheme

- (instancetype)init {
    self = [super init];
    if (self) {
        _themeType = AIThemeTypeClaudeCode;
        _displayName = @"Claude Code (Terminal)";

        // Colors - terminal green on black
        _backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:1.0]; // Near black #0D0D0D
        _surfaceColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];       // Slightly lighter #1A1A1A
        _primaryColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.2 alpha:1.0];       // Terminal green #00D932
        _secondaryColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];   // #262626
        _accentColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.3 alpha:1.0];         // Bright green
        _textPrimaryColor = [UIColor colorWithRed:0.9 green:0.95 blue:0.9 alpha:1.0];    // Green-tinted white
        _textSecondaryColor = [UIColor colorWithRed:0.6 green:0.8 blue:0.65 alpha:1.0];  // Dim green
        _textMutedColor = [UIColor colorWithRed:0.4 green:0.6 blue:0.45 alpha:1.0];      // Muted green
        _separatorColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.1 alpha:1.0];       // Dark green lines
        _borderColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.1 alpha:1.0];          // Border green
        _inputBackgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
        _inputBorderColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.1 alpha:1.0];
        _buttonBackgroundColor = [UIColor colorWithRed:0.0 green:0.2 blue:0.05 alpha:1.0];
        _buttonTextColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.3 alpha:1.0];
        _navigationBarColor = [UIColor colorWithRed:0.0 green:0.08 blue:0.02 alpha:1.0];
        _navigationBarTextColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.3 alpha:1.0];
        _statusBarStyle = (id)[UIColor whiteColor]; // Light content
        _userMessageColor = [UIColor colorWithRed:0.0 green:0.3 blue:0.08 alpha:1.0];     // Dark green bubble
        _assistantMessageColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0]; // Near black
        _systemMessageColor = [UIColor colorWithRed:0.3 green:0.25 blue:0.0 alpha:1.0];   // Amber/yellow
        _streamingIndicatorColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.3 alpha:1.0];

        // Fonts - Monospace all the way
        _fontRegular = [UIFont fontWithName:@"Menlo" size:15];
        _fontMedium = [UIFont fontWithName:@"Menlo-Bold" size:15];
        _fontBold = [UIFont fontWithName:@"Menlo-Bold" size:15];
        _fontMonospace = [UIFont fontWithName:@"Menlo" size:14];
        _fontMonospaceSmall = [UIFont fontWithName:@"Menlo" size:12];
        _fontTitle = [UIFont fontWithName:@"Menlo-Bold" size:16];
        _fontCaption = [UIFont fontWithName:@"Menlo" size:11];

        // Metrics - terminal feel
        _cornerRadius = 0.0;           // Sharp corners
        _borderWidth = 1.0;
        _buttonHeight = 36.0;
        _inputHeight = 36.0;
        _cellPadding = 8.0;
        _navigationBarHeight = 32.0;
        _statusBarHeight = 20.0;

        // No shadows, no gradients
        _shadowOffset = CGSizeZero;
        _shadowRadius = 0.0;
        _shadowOpacity = 0.0;
        _useGradients = NO;
        _useTextures = NO;
        _useRoundedCorners = NO;
    }
    return self;
}

- (void)styleNavigationBar:(UINavigationBar *)navBar {
    navBar.barTintColor = self.navigationBarColor;
    navBar.tintColor = self.primaryColor;
    navBar.titleTextAttributes = @{
        NSFontAttributeName: self.fontTitle,
        NSForegroundColorAttributeName: self.navigationBarTextColor
    };
    navBar.translucent = NO;
    // ASCII-style border at bottom
    navBar.shadowImage = [self asciiBorderImage];
}

- (UIImage *)asciiBorderImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, self.separatorColor.CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, 1, 1));
    return UIGraphicsGetImageFromCurrentImageContext();
}

- (void)styleTableView:(UITableView *)tableView {
    [super styleTableView:tableView];
    tableView.separatorColor = self.separatorColor;
    tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    tableView.sectionIndexColor = self.primaryColor;
}

- (void)styleTableViewCell:(UITableViewCell *)cell {
    [super styleTableViewCell:cell];
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    cell.selectedBackgroundView = [[UIView alloc] init];
    cell.selectedBackgroundView.backgroundColor = [self.primaryColor colorWithAlphaComponent:0.1];
}

- (void)styleTextView:(UITextView *)textView {
    [super styleTextView:textView];
    textView.layer.borderWidth = 1.0;
    textView.layer.cornerRadius = 0;
    textView.font = self.fontMonospace;
}

- (void)styleTextField:(UITextField *)textField {
    [super styleTextField:textField];
    textField.layer.borderWidth = 1.0;
    textField.layer.cornerRadius = 0;
    textField.font = self.fontMonospace;
}

- (void)styleButton:(UIButton *)button forState:(UIControlState)state {
    [super styleButton:button forState:state];
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = self.borderColor.CGColor;
    button.layer.cornerRadius = 0;
    button.titleLabel.font = self.fontMonospace;
    // ASCII button style
    [button setTitleColor:self.buttonTextColor forState:UIControlStateNormal];
    [button setTitleColor:self.backgroundColor forState:UIControlStateHighlighted];
    [button setBackgroundColor:self.buttonBackgroundColor forState:UIControlStateNormal];
    [button setBackgroundColor:self.buttonTextColor forState:UIControlStateHighlighted];
}

- (void)styleLabel:(UILabel *)label style:(NSString *)style {
    // Everything monospace in Claude Code theme
    label.font = self.fontMonospace;
    label.textColor = self.textPrimaryColor;

    if ([style isEqualToString:@"caption"]) {
        label.font = self.fontCaption;
        label.textColor = self.textMutedColor;
    } else if ([style isEqualToString:@"secondary"]) {
        label.textColor = self.textSecondaryColor;
    } else if ([style isEqualToString:@"title"]) {
        label.font = self.fontTitle;
    }
}

- (void)styleSegmentedControl:(UISegmentedControl *)control {
    // ASCII-style segmented control
    [control removeAllSegments];
    control.tintColor = self.primaryColor;

    NSDictionary *normalAttrs = @{
        NSFontAttributeName: self.fontMonospaceSmall,
        NSForegroundColorAttributeName: self.textSecondaryColor
    };
    NSDictionary *selectedAttrs = @{
        NSFontAttributeName: self.fontMonospaceSmall,
        NSForegroundColorAttributeName: self.backgroundColor
    };
    [control setTitleTextAttributes:normalAttrs forState:UIControlStateNormal];
    [control setTitleTextAttributes:selectedAttrs forState:UIControlStateSelected];

    // Custom background - ASCII box drawing
    [control setBackgroundImage:[self asciiSegmentBackground:NO] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [control setBackgroundImage:[self asciiSegmentBackground:YES] forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
    [control setDividerImage:[self asciiDividerImage] forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
}

- (UIImage *)asciiSegmentBackground:(BOOL)selected {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(80, 32), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    if (selected) {
        CGContextSetFillColorWithColor(ctx, self.primaryColor.CGColor);
    } else {
        CGContextSetFillColorWithColor(ctx, self.surfaceColor.CGColor);
    }
    CGContextFillRect(ctx, CGRectMake(0, 0, 80, 32));

    // Border
    CGContextSetStrokeColorWithColor(ctx, self.borderColor.CGColor);
    CGContextSetLineWidth(ctx, 1.0);
    CGContextStrokeRect(ctx, CGRectInset(CGRectMake(0, 0, 80, 32), 0.5, 0.5));

    // Corner brackets for ASCII feel
    CGContextSetStrokeColorWithColor(ctx, selected ? self.backgroundColor.CGColor : self.primaryColor.CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    // Top-left
    CGContextMoveToPoint(ctx, 2, 4);
    CGContextAddLineToPoint(ctx, 2, 2);
    CGContextAddLineToPoint(ctx, 4, 2);
    // Bottom-right
    CGContextMoveToPoint(ctx, 76, 28);
    CGContextAddLineToPoint(ctx, 78, 28);
    CGContextAddLineToPoint(ctx, 78, 30);
    CGContextStrokePath(ctx);

    return UIGraphicsGetImageFromCurrentImageContext();
}

- (UIImage *)asciiDividerImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(2, 32), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, self.borderColor.CGColor);
    CGContextSetLineWidth(ctx, 1.0);
    CGContextMoveToPoint(ctx, 1, 4);
    CGContextAddLineToPoint(ctx, 1, 28);
    CGContextStrokePath(ctx);
    return UIGraphicsGetImageFromCurrentImageContext();
}

- (void)styleSwitch:(UISwitch *)switchControl {
    switchControl.onTintColor = self.primaryColor;
    switchControl.tintColor = self.borderColor;
    switchControl.thumbTintColor = self.backgroundColor;
    // Make it look like [ ] / [X]
    switchControl.layer.borderWidth = 1.0;
    switchControl.layer.borderColor = self.borderColor.CGColor;
    switchControl.layer.cornerRadius = 0;
}

- (void)styleSlider:(UISlider *)slider {
    slider.minimumTrackTintColor = self.primaryColor;
    slider.maximumTrackTintColor = self.borderColor;
    slider.thumbTintColor = self.primaryColor;
    // ASCII thumb
    [slider setThumbImage:[self asciiSliderThumb] forState:UIControlStateNormal];
}

- (UIImage *)asciiSliderThumb {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, self.primaryColor.CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, 20, 20));
    CGContextSetStrokeColorWithColor(ctx, self.backgroundColor.CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    // ASCII "▮" style
    CGContextMoveToPoint(ctx, 10, 2);
    CGContextAddLineToPoint(ctx, 10, 18);
    CGContextStrokePath(ctx);
    return UIGraphicsGetImageFromCurrentImageContext();
}

- (void)styleProgressView:(UIProgressView *)progressView {
    progressView.progressTintColor = self.primaryColor;
    progressView.trackTintColor = self.borderColor;
    // ASCII progress bar
    [progressView setProgressImage:[self asciiProgressImage] forState:UIControlStateNormal];
}

- (UIImage *)asciiProgressImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 4), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, self.primaryColor.CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, 20, 4));
    return UIGraphicsGetImageFromCurrentImageContext();
}

#pragma mark - Message Bubbles (ASCII-style)

- (UIColor *)bubbleColorForRole:(AIMessageRole)role isOutgoing:(BOOL)outgoing {
    if (outgoing) return self.userMessageColor;
    switch (role) {
        case AIMessageRoleAssistant: return self.assistantMessageColor;
        case AIMessageRoleSystem: return self.systemMessageColor;
        default: return self.surfaceColor;
    }
}

- (UIEdgeInsets)bubbleInsetsForRole:(AIMessageRole)role isOutgoing:(BOOL)outgoing {
    return UIEdgeInsetsMake(8, 12, 8, 12);
}

- (CGFloat)bubbleCornerRadiusForRole:(AIMessageRole)role isOutgoing:(BOOL)outgoing {
    return 0; // Sharp corners for ASCII feel
}

- (BOOL)shouldShowTailForRole:(AIMessageRole)role isOutgoing:(BOOL)outgoing {
    return NO; // No tails, use ASCII brackets instead
}

- (void)styleAlertView:(UIAlertView *)alertView {
    alertView.tintColor = self.primaryColor;
    // Add ASCII-style brackets to title
    if (alertView.title && ![alertView.title hasPrefix:@"> "]) {
        alertView.title = [NSString stringWithFormat:@"> %@ <", alertView.title];
    }
}

- (void)styleActionSheet:(UIActionSheet *)actionSheet {
    actionSheet.tintColor = self.primaryColor;
}

- (void)styleBarButton:(UIBarButtonItem *)barButton withTheme:(id<AITheme>)theme {
    [super styleBarButton:barButton withTheme:theme];
    barButton.tintColor = self.navigationBarTextColor;
    [barButton setTitleTextAttributes:@{
        NSFontAttributeName: self.fontMonospaceSmall,
        NSForegroundColorAttributeName: self.navigationBarTextColor
    } forState:UIControlStateNormal];
}

@end

#pragma mark - Theme Manager

@interface AIThemeManager ()
@property (nonatomic, strong) NSMutableDictionary *themes;
@property (nonatomic, assign) AIThemeType currentThemeType;
@property (nonatomic, strong) id<AITheme> currentTheme;
@end

@implementation AIThemeManager

+ (instancetype)sharedManager {
    static AIThemeManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _themes = [NSMutableDictionary dictionary];

        // Register built-in themes
        [self registerTheme:[[AISkeuomorphicTheme alloc] init] forType:AIThemeTypeSkeuomorphic];
        [self registerTheme:[[AIMinimalistTheme alloc] init] forType:AIThemeTypeMinimalist];
        [self registerTheme:[[AIClaudeCodeTheme alloc] init] forType:AIThemeTypeClaudeCode];

        // Default to Skeuomorphic for iOS 6, Minimalist for modern
        #if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
        _currentThemeType = AIThemeTypeSkeuomorphic;
        #else
        if (NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_6_1) {
            _currentThemeType = AIThemeTypeSkeuomorphic;
        } else {
            _currentThemeType = AIThemeTypeMinimalist;
        }
        #endif
        _currentTheme = _themes[@(_currentThemeType)];
    }
    return self;
}

- (void)setThemeType:(AIThemeType)type animated:(BOOL)animated {
    id<AITheme> newTheme = _themes[@(type)];
    if (!newTheme) return;

    _currentThemeType = type;
    _currentTheme = newTheme;

    // Post notification for UI updates
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AIThemeDidChangeNotification"
                                                        object:self
                                                      userInfo:@{@"themeType": @(type)}];
}

- (void)registerTheme:(id<AITheme>)theme forType:(AIThemeType)type {
    _themes[@(type)] = theme;
}

- (id<AITheme>)themeForType:(AIThemeType)type {
    return _themes[@(type)];
}

- (UIColor *)colorForKey:(NSString *)key {
    SEL selector = NSSelectorFromString([key stringByAppendingString:@"Color"]);
    if ([_currentTheme respondsToSelector:selector]) {
        return [_currentTheme performSelector:selector];
    }
    return nil;
}

- (UIFont *)fontForKey:(NSString *)key {
    SEL selector = NSSelectorFromString([key stringByAppendingString:@"Font"]);
    if ([_currentTheme respondsToSelector:selector]) {
        return [_currentTheme performSelector:selector];
    }
    return nil;
}

@end