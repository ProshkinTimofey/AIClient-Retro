//
//  AIAttachmentCell.m
//  AIClient
//

#import "AIAttachmentCell.h"
#import "AIAttachment.h"

@interface AIAttachmentCell ()

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *fileNameLabel;
@property (nonatomic, strong) UIButton *removeButton;
@property (nonatomic, strong) UIActivityIndicatorView *progressIndicator;
@property (nonatomic, strong) UIView *overlayView;

@end

@implementation AIAttachmentCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.layer.cornerRadius = 12;
    self.clipsToBounds = YES;

    // Image view
    self.imageView = [[UIImageView alloc] init];
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.clipsToBounds = YES;
    [self.contentView addSubview:self.imageView];

    // File name label
    self.fileNameLabel = [[UILabel alloc] init];
    self.fileNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.fileNameLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    self.fileNameLabel.textColor = [UIColor secondaryLabel];
    self.fileNameLabel.numberOfLines = 2;
    self.fileNameLabel.textAlignment = NSTextAlignmentCenter;
    [self.contentView addSubview:self.fileNameLabel];

    // Remove button
    self.removeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.removeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.removeButton.setImage:[UIImage systemImageNamed:@"xmark.circle.fill"], forState:UIControlStateNormal];
    self.removeButton.tintColor = [UIColor systemRedColor];
    self.removeButton.backgroundColor = [UIColor systemBackgroundColor];
    self.removeButton.layer.cornerRadius = 12;
    self.removeButton.clipsToBounds = YES;
    [self.removeButton addTarget:self action:@selector(removeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.removeButton];

    // Progress indicator
    self.progressIndicator = [[UIActivityIndicatorView alloc] initWithStyle:UIActivityIndicatorViewStyleMedium];
    self.progressIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressIndicator.hidesWhenStopped = YES;
    [self.contentView addSubview:self.progressIndicator];

    // Overlay for upload state
    self.overlayView = [[UIView alloc] init];
    self.overlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.overlayView.backgroundColor = [UIColor blackColor].colorWithAlphaComponent(0.5);
    self.overlayView.hidden = YES;
    [self.contentView addSubview:self.overlayView];

    [NSLayoutConstraint activateConstraints:@[
        self.imageView.topAnchor.constraintEqualToAnchor:self.contentView.topAnchor,
        self.imageView.leadingAnchor.constraintEqualToAnchor:self.contentView.leadingAnchor,
        self.imageView.trailingAnchor.constraintEqualToAnchor:self.contentView.trailingAnchor,
        self.imageView.bottomAnchor.constraintEqualToAnchor:self.contentView.bottomAnchor,

        self.fileNameLabel.leadingAnchor.constraintEqualToAnchor:self.contentView.leadingAnchor constant:4],
        self.fileNameLabel.trailingAnchor.constraintEqualToAnchor:self.contentView.trailingAnchor constant:-4],
        self.fileNameLabel.bottomAnchor.constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4],

        self.removeButton.topAnchor.constraintEqualToAnchor:self.contentView.topAnchor constant:4],
        self.removeButton.trailingAnchor.constraintEqualToAnchor:self.contentView.trailingAnchor constant:-4],
        self.removeButton.widthAnchor.constraintEqualToConstant(24)],
        self.removeButton.heightAnchor.constraintEqualToConstant(24)],

        self.progressIndicator.centerXAnchor.constraintEqualToAnchor:self.contentView.centerXAnchor],
        self.progressIndicator.centerYAnchor.constraintEqualToAnchor:self.contentView.centerYAnchor],

        self.overlayView.topAnchor.constraintEqualToAnchor:self.contentView.topAnchor],
        self.overlayView.leadingAnchor.constraintEqualToAnchor:self.contentView.leadingAnchor],
        self.overlayView.trailingAnchor.constraintEqualToAnchor:self.contentView.trailingAnchor],
        self.overlayView.bottomAnchor.constraintEqualToAnchor:self.contentView.bottomAnchor],
    ]);
}

- (void)configureWithAttachment:(AIAttachment *)attachment {
    _attachment = attachment;

    if (attachment.type == AIAttachmentTypeImage) {
        self.fileNameLabel.hidden = YES;
        self.imageView.hidden = NO;

        if (attachment.thumbnail) {
            self.imageView.image = attachment.thumbnail;
        } else {
            // Load thumbnail async
            [attachment generateThumbnailWithSize:self.bounds.size completion:^(UIImage *thumb) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.attachment == attachment) {
                        self.imageView.image = thumb;
                    }
                });
            }];
        }
    } else {
        self.fileNameLabel.hidden = NO;
        self.imageView.hidden = YES;
        self.fileNameLabel.text = attachment.fileName;
        self.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
    }

    // Upload state
    if (attachment.isUploading) {
        self.overlayView.hidden = NO;
        [self.progressIndicator startAnimating];
        self.removeButton.hidden = YES;
    } else if (attachment.isUploaded) {
        self.overlayView.hidden = YES;
        [self.progressIndicator stopAnimating];
        self.removeButton.hidden = NO;
    } else {
        self.overlayView.hidden = YES;
        [self.progressIndicator stopAnimating];
        self.removeButton.hidden = NO;
    }
}

- (void)removeTapped {
    [self.delegate attachmentCellDidTapRemove:self];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.imageView.image = nil;
    self.fileNameLabel.text = nil;
    self.attachment = nil;
    self.overlayView.hidden = YES;
    [self.progressIndicator stopAnimating];
}

@end