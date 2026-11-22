//
//  AIImagePreviewView.m
//  AIClient
//

#import "AIImagePreviewView.h"
#import "AIAttachment.h"

@interface AIImagePreviewView ()

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIButton *tapButton;

@end

@implementation AIImagePreviewView

- (instancetype)initWithAttachment:(AIAttachment *)attachment {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _attachment = attachment;
        [self setupViews];
        [self loadImage];
    }
    return self;
}

- (void)setupViews {
    self.layer.cornerRadius = 12;
    self.clipsToBounds = YES;
    self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];

    self.imageView = [[UIImageView alloc] init];
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.clipsToBounds = YES;
    [self addSubview:self.imageView];

    self.tapButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.tapButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tapButton addTarget:self action:@selector(imageTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.tapButton];

    [NSLayoutConstraint activateConstraints:@[
        self.imageView.topAnchor.constraintEqualToAnchor:self.topAnchor,
        self.imageView.leadingAnchor.constraintEqualToAnchor:self.leadingAnchor,
        self.imageView.trailingAnchor.constraintEqualToAnchor:self.trailingAnchor,
        self.imageView.bottomAnchor.constraintEqualToAnchor:self.bottomAnchor,

        self.tapButton.topAnchor.constraintEqualToAnchor:self.topAnchor,
        self.tapButton.leadingAnchor.constraintEqualToAnchor:self.leadingAnchor,
        self.tapButton.trailingAnchor.constraintEqualToAnchor:self.trailingAnchor,
        self.tapButton.bottomAnchor.constraintEqualToAnchor:self.bottomAnchor,
    ]];

    // Height constraint for chat bubble
    self.heightAnchor.constraintEqualToConstant(200).active = YES;
}

- (void)loadImage {
    if (_attachment.thumbnail) {
        self.imageView.image = _attachment.thumbnail;
    } else {
        [_attachment generateThumbnailWithSize:CGSizeMake(300, 200) completion:^(UIImage *thumb) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.imageView.image = thumb;
            });
        }];
    }
}

- (void)imageTapped {
    // Present full-screen image viewer
    UIViewController *vc = [self findViewController];
    if (vc && _attachment) {
        // Quick look or custom full screen
        QLPreviewController *preview = [[QLPreviewController alloc] init];
        preview.dataSource = self;
        [vc presentViewController:preview animated:YES completion:nil];
    }
}

- (UIViewController *)findViewController {
    UIResponder *responder = self.nextResponder;
    while (responder && ![responder isKindOfClass:[UIViewController class]]) {
        responder = responder.nextResponder;
    }
    return (UIViewController *)responder;
}

@end

// QLPreviewControllerDataSource
#import <QuickLook/QuickLook.h>

@interface AIImagePreviewView () <QLPreviewControllerDataSource>
@end

@implementation AIImagePreviewView (QLPreview)

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return 1;
}

- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    if (_attachment.source == AIAttachmentSourceLocal) {
        return [NSURL fileURLWithPath:_attachment.localPath];
    } else if (_attachment.source == AIAttachmentSourceRemote) {
        return [NSURL URLWithString:_attachment.remoteURL];
    }
    return nil;
}

@end