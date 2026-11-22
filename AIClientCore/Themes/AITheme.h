//
//  AITheme.h
//  AIClient
//
//  Theme system supporting Skeuomorphic (iOS 6), Minimalist (iOS 13+), and Claude Code (monospace terminal)
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, AIThemeType) {
    AIThemeTypeSkeuomorphic = 0,  // iOS 6 style: leather, metal, gradients, shadows
    AIThemeTypeMinimalist = 1,    // iOS 13+ style: flat, clean, system colors
    AIThemeTypeClaudeCode = 2,    // Terminal: monospace, green-on-black, ASCII borders
};

@protocol AITheme <NSObject>

@property (nonatomic, readonly) AIThemeType themeType;
@property (nonatomic, readonly, copy) NSString *displayName;

// Colors
@property (nonatomic, readonly, strong) UIColor *backgroundColor;
@property (nonatomic, readonly, strong) UIColor *surfaceColor;
@property (nonatomic, readonly, strong) UIColor *primaryColor;
@property (nonatomic, readonly, strong) UIColor *secondaryColor;
@property (nonatomic, readonly, strong) UIColor *accentColor;
@property (nonatomic, readonly, strong) UIColor *textPrimaryColor;
@property (nonatomic, readonly, strong) UIColor *textSecondaryColor;
@property (nonatomic, readonly, strong) UIColor *textMutedColor;
@property (nonatomic, readonly, strong) UIColor *separatorColor;
@property (nonatomic, readonly, strong) UIColor *borderColor;
@property (nonatomic, readonly, strong) UIColor *inputBackgroundColor;
@property (nonatomic, readonly, strong) UIColor *inputBorderColor;
@property (nonatomic, readonly, strong) UIColor *buttonBackgroundColor;
@property (nonatomic, readonly, strong) UIColor *buttonTextColor;
@property (nonatomic, readonly, strong) UIColor *navigationBarColor;
@property (nonatomic, readonly, strong) UIColor *navigationBarTextColor;
@property (nonatomic, readonly, strong) UIColor *statusBarStyle; // UIStatusBarStyle
@property (nonatomic, readonly, strong) UIColor *userMessageColor;
@property (nonatomic, readonly, strong) UIColor *assistantMessageColor;
@property (nonatomic, readonly, strong) UIColor *systemMessageColor;
@property (nonatomic, readonly, strong) UIColor *streamingIndicatorColor;

// Fonts
@property (nonatomic, readonly, strong) UIFont *fontRegular;
@property (nonatomic, readonly, strong) UIFont *fontMedium;
@property (nonatomic, readonly, strong) UIFont *fontBold;
@property (nonatomic, readonly, strong) UIFont *fontMonospace;
@property (nonatomic, readonly, strong) UIFont *fontMonospaceSmall;
@property (nonatomic, readonly, strong) UIFont *fontTitle;
@property (nonatomic, readonly, strong) UIFont *fontCaption;

// Metrics
@property (nonatomic, readonly) CGFloat cornerRadius;
@property (nonatomic, readonly) CGFloat borderWidth;
@property (nonatomic, readonly) CGFloat buttonHeight;
@property (nonatomic, readonly) CGFloat inputHeight;
@property (nonatomic, readonly) CGFloat cellPadding;
@property (nonatomic, readonly) CGFloat navigationBarHeight;
@property (nonatomic, readonly) CGFloat statusBarHeight;

// Shadows & Effects
@property (nonatomic, readonly) CGSize shadowOffset;
@property (nonatomic, readonly) CGFloat shadowRadius;
@property (nonatomic, readonly) CGFloat shadowOpacity;
@property (nonatomic, readonly) BOOL useGradients;
@property (nonatomic, readonly) BOOL useTextures;
@property (nonatomic, readonly) BOOL useRoundedCorners;

// Images/Textures
- (UIImage *)backgroundTexture;
- (UIImage *)navigationBarTexture;
- (UIImage *)buttonTextureForState:(UIControlState)state;
- (UIImage *)cellBackgroundTexture;

// Component styling
- (void)styleNavigationBar:(UINavigationBar *)navBar;
- (void)styleToolbar:(UIToolbar *)toolbar;
- (void)styleTableView:(UITableView *)tableView;
- (void)styleTableViewCell:(UITableViewCell *)cell;
- (void)styleTextView:(UITextView *)textView;
- (void)styleTextField:(UITextField *)textField;
- (void)styleButton:(UIButton *)button forState:(UIControlState)state;
- (void)styleLabel:(UILabel *)label style:(NSString *)style; // "title", "body", "caption", "monospace"
- (void)styleSegmentedControl:(UISegmentedControl *)control;
- (void)styleSwitch:(UISwitch *)switchControl;
- (void)styleSlider:(UISlider *)slider;
- (void)styleProgressView:(UIProgressView *)progressView;
- (void)styleActivityIndicator:(UIActivityIndicatorView *)indicator;
- (void)styleAlertView:(UIAlertView *)alertView;
- (void)styleActionSheet:(UIActionSheet *)actionSheet;
- (void)styleBarButton:(UIBarButtonItem *)barButton withTheme:(id<AITheme>)theme;

// Message bubble styling
- (UIColor *)bubbleColorForRole:(AIMessageRole)role isOutgoing:(BOOL)outgoing;
- (UIEdgeInsets)bubbleInsetsForRole:(AIMessageRole)role isOutgoing:(BOOL)outgoing;
- (CGFloat)bubbleCornerRadiusForRole:(AIMessageRole)role isOutgoing:(BOOL)outgoing;
- (BOOL)shouldShowTailForRole:(AIMessageRole)role isOutgoing:(BOOL)outgoing;

@end

// Theme Manager
@interface AIThemeManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, readonly) AIThemeType currentThemeType;
@property (nonatomic, readonly, strong) id<AITheme> currentTheme;

- (void)setThemeType:(AIThemeType)type animated:(BOOL)animated;
- (void)registerTheme:(id<AITheme>)theme forType:(AIThemeType)type;
- (id<AITheme>)themeForType:(AIThemeType)type;

// Convenience
- (UIColor *)colorForKey:(NSString *)key;
- (UIFont *)fontForKey:(NSString *)key;

@end

// Theme keys for dynamic colors
extern NSString *const AIThemeColorBackground;
extern NSString *const AIThemeColorSurface;
extern NSString *const AIThemeColorPrimary;
extern NSString *const AIThemeColorSecondary;
extern NSString *const AIThemeColorAccent;
extern NSString *const AIThemeColorTextPrimary;
extern NSString *const AIThemeColorTextSecondary;
extern NSString *const AIThemeColorTextMuted;
extern NSString *const AIThemeColorSeparator;
extern NSString *const AIThemeColorBorder;
extern NSString *const AIThemeColorInputBackground;
extern NSString *const AIThemeColorInputBorder;
extern NSString *const AIThemeColorButtonBackground;
extern NSString *const AIThemeColorButtonText;
extern NSString *const AIThemeColorNavigationBar;
extern NSString *const AIThemeColorNavigationBarText;
extern NSString *const AIThemeColorUserMessage;
extern NSString *const AIThemeColorAssistantMessage;
extern NSString *const AIThemeColorSystemMessage;
extern NSString *const AIThemeColorStreamingIndicator;

// Font keys
extern NSString *const AIThemeFontRegular;
extern NSString *const AIThemeFontMedium;
extern NSString *const AIThemeFontBold;
extern NSString *const AIThemeFontMonospace;
extern NSString *const AIThemeFontMonospaceSmall;
extern NSString *const AIThemeFontTitle;
extern NSString *const AIThemeFontCaption;