//
//  AITerminalInputView.m
//  AIClient
//
//  Theme-aware input view with manual layout (no Auto Layout)
//

#import "AITerminalInputView.h"
#import "AIAttachment.h"
#import "AITheme.h"

NSString *const AITerminalInputViewHeightDidChangeNotification = @"AITerminalInputViewHeightDidChangeNotification";

@interface AITerminalInputView () <UITextViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UILabel *promptLabel;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIView *attachmentsBar;
@property (nonatomic, strong) UICollectionView *attachmentsCollection;
@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UIBarButtonItem *sendButton;
@property (nonatomic, assign) BOOL isFirstLayout;

@end

@implementation AITerminalInputView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _attachments = @[];
        _isFirstLayout = YES;
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    // Prompt label (>>>)
    self.promptLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.promptLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.promptLabel.numberOfLines = 1;
    [self addSubview:self.promptLabel];

    // Text view
    self.textView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.textView.backgroundColor = [UIColor clearColor];
    self.textView.font = [UIFont fontWithName:@"Courier" size:14];
    self.textView.textColor = [UIColor whiteColor];
    self.textView.textContainerInset = UIEdgeInsetsZero;
    self.textView.textContainer.lineFragmentPadding = 0;
    self.textView.delegate = self;
    self.textView.isScrollEnabled = NO;
    self.textView.returnKeyType = UIReturnKeySend;
    [self addSubview:self.textView];

    // Attachments bar (horizontal scroll)
    self.attachmentsBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.attachmentsBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.attachmentsBar.hidden = YES;
    [self addSubview:self.attachmentsBar];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize = CGSizeMake(80, 36);
    layout.minimumInteritemSpacing = 6;
    layout.sectionInset = UIEdgeInsetsMake(4, 8, 4, 8);

    self.attachmentsCollection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.attachmentsCollection.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.attachmentsCollection.backgroundColor = [UIColor clearColor];
    self.attachmentsCollection.dataSource = self;
    self.attachmentsCollection.delegate = self;
    self.attachmentsCollection.showsHorizontalScrollIndicator = NO;
    [self.attachmentsCollection registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"AttCell"];
    [self.attachmentsBar addSubview:self.attachmentsCollection];

    // Toolbar with action buttons
    self.toolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];
    self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.toolbar.barStyle = UIBarStyleBlack;

    UIBarButtonItem *attachBtn = [[UIBarButtonItem alloc] initWithTitle:@"Attach" style:UIBarButtonItemStyleBordered target:self action:@selector(attachTapped)];
    UIBarButtonItem *genBtn = [[UIBarButtonItem alloc] initWithTitle:@"Generate" style:UIBarButtonItemStyleBordered target:self action:@selector(genTapped)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    self.sendButton = [[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStyleDone target:self action:@selector(sendTapped)];
    self.sendButton.enabled = NO;

    self.toolbar.items = @[attachBtn, flex, genBtn, flex, self.sendButton];
    [self addSubview:self.toolbar];

    // Initial theme (will be updated by parent)
    [self applyDefaultStyle];
}

- (void)applyDefaultStyle {
    self.backgroundColor = [UIColor blackColor];
    self.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1.0].CGColor;
    self.layer.borderWidth = 0.5;

    self.promptLabel.font = [UIFont fontWithName:@"Courier-Bold" size:14];
    self.promptLabel.textColor = [UIColor greenColor];
    self.promptLabel.text = @">>> ";

    self.textView.font = [UIFont fontWithName:@"Courier" size:14];
    self.textView.textColor = [UIColor whiteColor];
}

- (void)applyTheme:(id<AITheme>)theme {
    self.backgroundColor = theme.inputBackgroundColor;
    self.layer.borderColor = theme.inputBorderColor.CGColor;
    self.layer.borderWidth = theme.borderWidth;

    [theme styleLabel:self.promptLabel style:@"monospace"];
    self.promptLabel.textColor = theme.primaryColor;

    [theme styleTextView:self.textView];

    self.attachmentsBar.backgroundColor = theme.surfaceColor;
    self.attachmentsCollection.backgroundColor = theme.surfaceColor;

    [theme styleToolbar:self.toolbar];
    self.toolbar.tintColor = theme.primaryColor;

    // Update bar button items
    for (UIBarButtonItem *item in self.toolbar.items) {
        [theme styleBarButton:item withTheme:theme];
    }

    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    if (_isFirstLayout) {
        _isFirstLayout = NO;
    }

    CGRect bounds = self.bounds;
    CGFloat padding = 8;
    CGFloat promptWidth = 48; // ">>> " width
    CGFloat toolbarHeight = 44;
    CGFloat attachmentsBarHeight = self.attachmentsBar.hidden ? 0 : 44;

    // Toolbar at bottom
    self.toolbar.frame = CGRectMake(0, bounds.size.height - toolbarHeight, bounds.size.width, toolbarHeight);

    // Attachments bar above toolbar
    self.attachmentsBar.frame = CGRectMake(0, bounds.size.height - toolbarHeight - attachmentsBarHeight, bounds.size.width, attachmentsBarHeight);
    self.attachmentsCollection.frame = self.attachmentsBar.bounds;

    // Prompt label top-left
    self.promptLabel.frame = CGRectMake(padding, padding, promptWidth, 20);

    // Text view next to prompt, above attachments bar
    CGFloat textViewX = padding + promptWidth + 4;
    CGFloat textViewY = padding;
    CGFloat textViewWidth = bounds.size.width - textViewX - padding;
    CGFloat textViewMaxHeight = bounds.size.height - toolbarHeight - attachmentsBarHeight - padding * 2;

    CGSize textSize = [self.textView sizeThatFits:CGSizeMake(textViewWidth, textViewMaxHeight)];
    CGFloat textViewHeight = MIN(textSize.height + 8, textViewMaxHeight);
    textViewHeight = MAX(textViewHeight, 28); // Minimum height

    self.textView.frame = CGRectMake(textViewX, textViewY, textViewWidth, textViewHeight);

    // Update intrinsic content size for parent
    CGFloat totalHeight = toolbarHeight + attachmentsBarHeight + padding * 2 + textViewHeight;
    if (fabs(totalHeight - self.frame.size.height) > 1) {
        [self notifyHeightChange:totalHeight];
    }
}

- (void)notifyHeightChange:(CGFloat)height {
    [[NSNotificationCenter defaultCenter] postNotificationName:AITerminalInputViewHeightDidChangeNotification
                                                        object:self
                                                      userInfo:@{@"height": @(height)}];
    if ([self.delegate respondsToSelector:@selector(terminalInputViewHeightDidChange:)]) {
        [self.delegate terminalInputViewHeightDidChange:self];
    }
}

#pragma mark - Actions

- (void)sendTapped {
    NSString *text = self.textView.text ?: @"";
    if (text.length > 0 || self.attachments.count > 0) {
        [self.delegate terminalInputView:self didSendText:text attachments:self.attachments];
        [self clearInput];
    }
}

- (void)attachTapped {
    [self.delegate terminalInputViewDidTapAttach:self];
}

- (void)genTapped {
    [self.delegate terminalInputViewDidTapImageGen:self];
}

- (void)clearInput {
    self.textView.text = @"";
    self.attachments = @[];
    self.attachmentsBar.hidden = YES;
    [self.attachmentsCollection reloadData];
    self.sendButton.enabled = NO;
    [self setNeedsLayout];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)tv {
    self.sendButton.enabled = tv.text.length > 0 || self.attachments.count > 0;
    [self setNeedsLayout];
    [self.delegate terminalInputViewHeightDidChange:self];
}

- (BOOL)textView:(UITextView *)tv shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text isEqualToString:@"\n"]) {
        if (tv.text.length > 0 || self.attachments.count > 0) {
            [self sendTapped];
        }
        return NO;
    }
    return YES;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)s {
    return self.attachments.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    UICollectionViewCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"AttCell" forIndexPath:ip];
    AIAttachment *att = self.attachments[ip.row];

    [cell.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    id<AITheme> theme = [[AIThemeManager sharedManager] currentTheme];

    UILabel *label = [[UILabel alloc] initWithFrame:cell.contentView.bounds];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [theme styleLabel:label style:@"caption"];
    label.backgroundColor = theme.surfaceColor;
    label.layer.borderColor = theme.borderColor.CGColor;
    label.layer.borderWidth = theme.borderWidth;
    label.layer.cornerRadius = theme.useRoundedCorners ? 4 : 0;
    label.clipsToBounds = YES;
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;

    if (att.type == AIAttachmentTypeImage) {
        label.text = [NSString stringWithFormat:@"[IMG] %@", att.fileName];
    } else {
        label.text = [NSString stringWithFormat:@"[FILE] %@", att.fileName];
    }

    // Remove button
    UIButton *removeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    removeBtn.frame = CGRectMake(cell.bounds.size.width - 20, 0, 20, 20);
    [theme styleButton:removeBtn forState:UIControlStateNormal];
    [removeBtn setTitle:@"x" forState:UIControlStateNormal];
    removeBtn.titleLabel.font = theme.fontCaption;
    removeBtn.tag = ip.row;
    [removeBtn addTarget:self action:@selector(removeAttachment:) forControlEvents:UIControlEventTouchUpInside];
    [cell.contentView addSubview:removeBtn];

    [cell.contentView addSubview:label];
    return cell;
}

- (void)removeAttachment:(UIButton *)btn {
    NSMutableArray *atts = [self.attachments mutableCopy];
    [atts removeObjectAtIndex:btn.tag];
    self.attachments = atts;
    [self.attachmentsCollection reloadData];
    self.attachmentsBar.hidden = self.attachments.count == 0;
    self.sendButton.enabled = self.textView.text.length > 0 || self.attachments.count > 0;
    [self setNeedsLayout];
}

- (void)setAttachments:(NSArray<AIAttachment *> *)atts {
    _attachments = atts;
    self.attachmentsBar.hidden = atts.count == 0;
    [self.attachmentsCollection reloadData];
    [self setNeedsLayout];
}

@end