//
//  AIChatInputView.m
//  AIClient
//

#import "AIChatInputView.h"
#import "AIAttachment.h"
#import "AIAttachmentCell.h"

@interface AIChatInputView () <UITextViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, AIAttachmentCellDelegate>

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIButton *attachButton;
@property (nonatomic, strong) UIButton *imageGenButton;
@property (nonatomic, strong) UICollectionView *attachmentsCollectionView;
@property (nonatomic, strong) UIView *attachmentsContainer;
@property (nonatomic, strong) NSLayoutConstraint *textViewHeightConstraint;
@property (nonatomic, assign) CGFloat maxTextViewHeight;

@end

@implementation AIChatInputView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _attachments = @[];
        _maxTextViewHeight = 120;
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.backgroundColor = [UIColor systemBackgroundColor];
    self.layer.borderColor = [UIColor separatorColor].CGColor;
    self.layer.borderWidth = 0.5;

    // Attachments container
    self.attachmentsContainer = [[UIView alloc] init];
    self.attachmentsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.attachmentsContainer.hidden = YES;
    [self addSubview:self.attachmentsContainer];

    // Attachments collection view
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize = CGSizeMake(80, 80);
    layout.minimumInteritemSpacing = 8;
    layout.sectionInset = UIEdgeInsetsMake(8, 12, 8, 12);

    self.attachmentsCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.attachmentsCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.attachmentsCollectionView.backgroundColor = [UIColor clearColor];
    self.attachmentsCollectionView.dataSource = self;
    self.attachmentsCollectionView.delegate = self;
    self.attachmentsCollectionView.showsHorizontalScrollIndicator = NO;
    [self.attachmentsCollectionView registerClass:[AIAttachmentCell class] forCellWithReuseIdentifier:@"AttachmentCell"];
    [self.attachmentsContainer addSubview:self.attachmentsCollectionView];

    // Input row
    UIView *inputRow = [[UIView alloc] init];
    inputRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:inputRow];

    // Attach button
    self.attachButton = [self buttonWithImage:@"paperclip" action:@selector(attachTapped)];
    [inputRow addSubview:self.attachButton];

    // Text view container
    UIView *textViewContainer = [[UIView alloc] init];
    textViewContainer.translatesAutoresizingMaskIntoConstraints = NO;
    textViewContainer.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    textViewContainer.layer.cornerRadius = 20;
    textViewContainer.layer.maskedCorners = kCALayerMaskedCorners;
    [inputRow addSubview:textViewContainer];

    // Placeholder
    self.placeholderLabel = [[UILabel alloc] init];
    self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeholderLabel.text = @"Message";
    self.placeholderLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.placeholderLabel.textColor = [UIColor tertiaryLabel];
    [textViewContainer addSubview:self.placeholderLabel];

    // Text view
    self.textView = [[UITextView alloc] init];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.backgroundColor = [UIColor clearColor];
    self.textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.textView.textColor = [UIColor label];
    self.textView.textContainerInset = UIEdgeInsetsMake(8, 12, 8, 12);
    self.textView.delegate = self;
    self.textView.isScrollEnabled = NO;
    self.textView.returnKeyType = UIReturnKeySend;
    [textViewContainer addSubview:self.textView];

    // Image gen button
    self.imageGenButton = [self buttonWithImage:@"sparkles" action:@selector(imageGenTapped)];
    [inputRow addSubview:self.imageGenButton];

    // Send button
    self.sendButton = [self buttonWithImage:@"arrow.up.circle.fill" action:@selector(sendTapped)];
    self.sendButton.tintColor = [UIColor systemBlueColor];
    self.sendButton.enabled = NO;
    [inputRow addSubview:self.sendButton];

    // Constraints
    self.textViewHeightConstraint = self.textView.heightAnchor.constraintEqualToConstant(44);

    [NSLayoutConstraint activateConstraints:@[
        // Attachments container
        self.attachmentsContainer.topAnchor.constraintEqualToAnchor:self.topAnchor,
        self.attachmentsContainer.leadingAnchor.constraintEqualToAnchor:self.leadingAnchor,
        self.attachmentsContainer.trailingAnchor.constraintEqualToAnchor:self.trailingAnchor,
        self.attachmentsContainer.heightAnchor.constraintEqualToConstant(100),

        // Attachments collection view
        self.attachmentsCollectionView.topAnchor.constraintEqualToAnchor:self.attachmentsContainer.topAnchor,
        self.attachmentsCollectionView.leadingAnchor.constraintEqualToAnchor:self.attachmentsContainer.leadingAnchor,
        self.attachmentsCollectionView.trailingAnchor.constraintEqualToAnchor:self.attachmentsContainer.trailingAnchor,
        self.attachmentsCollectionView.bottomAnchor.constraintEqualToAnchor:self.attachmentsContainer.bottomAnchor,

        // Input row
        inputRow.topAnchor.constraintEqualToAnchor:self.attachmentsContainer.bottomAnchor,
        inputRow.leadingAnchor.constraintEqualToAnchor:self.leadingAnchor constant:12,
        inputRow.trailingAnchor.constraintEqualToAnchor:self.trailingAnchor constant:-12,
        inputRow.bottomAnchor.constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-8,

        // Attach button
        self.attachButton.leadingAnchor.constraintEqualToAnchor:inputRow.leadingAnchor,
        self.attachButton.centerYAnchor.constraintEqualToAnchor:textViewContainer.centerYAnchor,
        self.attachButton.widthAnchor.constraintEqualToConstant(44),
        self.attachButton.heightAnchor.constraintEqualToConstant(44),

        // Text view container
        textViewContainer.leadingAnchor.constraintEqualToAnchor:self.attachButton.trailingAnchor constant:4,
        textViewContainer.centerYAnchor.constraintEqualToAnchor:inputRow.centerYAnchor,

        // Placeholder
        self.placeholderLabel.leadingAnchor.constraintEqualToAnchor:textViewContainer.leadingAnchor constant:16,
        self.placeholderLabel.centerYAnchor.constraintEqualToAnchor:textViewContainer.centerYAnchor,

        // Text view
        self.textView.topAnchor.constraintEqualToAnchor:textViewContainer.topAnchor,
        self.textView.leadingAnchor.constraintEqualToAnchor:textViewContainer.leadingAnchor,
        self.textView.trailingAnchor.constraintEqualToAnchor:textViewContainer.trailingAnchor,
        self.textView.bottomAnchor.constraintEqualToAnchor:textViewContainer.bottomAnchor,
        self.textViewHeightConstraint,

        // Image gen button
        self.imageGenButton.leadingAnchor.constraintEqualToAnchor:textViewContainer.trailingAnchor constant:4,
        self.imageGenButton.centerYAnchor.constraintEqualToAnchor:inputRow.centerYAnchor,
        self.imageGenButton.widthAnchor.constraintEqualToConstant(44),
        self.imageGenButton.heightAnchor.constraintEqualToConstant(44),

        // Send button
        self.sendButton.leadingAnchor.constraintEqualToAnchor:self.imageGenButton.trailingAnchor constant:4,
        self.sendButton.trailingAnchor.constraintEqualToAnchor:inputRow.trailingAnchor,
        self.sendButton.centerYAnchor.constraintEqualToAnchor:inputRow.centerYAnchor,
        self.sendButton.widthAnchor.constraintEqualToConstant(44),
        self.sendButton.heightAnchor.constraintEqualToConstant(44),
    ]];
}

- (UIButton *)buttonWithImage:(NSString *)systemName action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.setImage:[UIImage systemImageNamed:systemName], forState:UIControlStateNormal];
    button.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark - Actions

- (void)sendTapped {
    NSString *text = self.textView.text ?: @"";
    [self.delegate chatInputView:self didSendText:text attachments:self.attachments];
    [self clearInput];
}

- (void)attachTapped {
    [self.delegate chatInputViewDidTapAttach:self];
}

- (void)imageGenTapped {
    [self.delegate chatInputViewDidTapImageGen:self];
}

- (void)clearInput {
    self.textView.text = @"";
    self.placeholderLabel.hidden = NO;
    self.sendButton.enabled = NO;
    self.attachments = @[];
    self.attachmentsContainer.hidden = YES;
    [self.attachmentsCollectionView reloadData];
    [self updateTextViewHeight];
    [self.delegate chatInputViewHeightDidChange:self];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    self.placeholderLabel.hidden = textView.text.length > 0;
    self.sendButton.enabled = textView.text.length > 0 || self.attachments.count > 0;
    [self updateTextViewHeight];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text isEqualToString:@"\n"]) {
        if (textView.text.length > 0) {
            [self sendTapped];
        }
        return NO;
    }
    return YES;
}

- (void)updateTextViewHeight {
    CGSize size = [self.textView sizeThatFits:CGSizeMake(self.textView.frame.size.width, self.maxTextViewHeight)];
    CGFloat newHeight = MIN(MAX(size.height, 44), self.maxTextViewHeight);
    self.textViewHeightConstraint.constant = newHeight;
    self.textView.isScrollEnabled = size.height > self.maxTextViewHeight;

    [self.delegate chatInputViewHeightDidChange:self];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.attachments.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    AIAttachmentCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AttachmentCell" forIndexPath:indexPath];
    cell.delegate = self;
    [cell configureWithAttachment:self.attachments[indexPath.row]];
    return cell;
}

#pragma mark - AIAttachmentCellDelegate

- (void)attachmentCellDidTapRemove:(AIAttachmentCell *)cell {
    NSIndexPath *indexPath = [self.attachmentsCollectionView indexPathForCell:cell];
    if (indexPath) {
        NSMutableArray *atts = [self.attachments mutableCopy];
        [atts removeObjectAtIndex:indexPath.row];
        self.attachments = atts;
        [self.attachmentsCollectionView deleteItemsAtIndexPaths:@[indexPath]];
        self.attachmentsContainer.hidden = self.attachments.count == 0;
        self.sendButton.enabled = self.textView.text.length > 0 || self.attachments.count > 0;
        [self.delegate chatInputViewHeightDidChange:self];
    }
}

- (void)setAttachments:(NSArray<AIAttachment *> *)attachments {
    _attachments = attachments;
    self.attachmentsContainer.hidden = attachments.count == 0;
    [self.attachmentsCollectionView reloadData];
    [self updateTextViewHeight];
}

@end