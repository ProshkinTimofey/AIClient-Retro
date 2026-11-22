//
//  AIPasteboardMonitor.m
//  AIClient
//

#import "AIPasteboardMonitor.h"

@interface AIPasteboardMonitor ()

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) NSString *lastString;
@property (nonatomic, copy) NSData *lastImageData;

@end

@implementation AIPasteboardMonitor

+ (instancetype)sharedMonitor {
    static dispatch_once_t onceToken;
    static AIPasteboardMonitor *shared = nil;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (void)startMonitoring {
    if (_isMonitoring) return;
    _isMonitoring = YES;

    // Initial snapshot
    [self checkPasteboard];

    // Poll every 1 second
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkPasteboard) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)stopMonitoring {
    _isMonitoring = NO;
    [self.timer invalidate];
    self.timer = nil;
}

- (void)checkPasteboard {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];

    // Check for text
    if (pasteboard.string && ![pasteboard.string isEqualToString:self.lastString]) {
        self.lastString = pasteboard.string;
        if ([self.delegate respondsToSelector:@selector(pasteboardMonitor:didDetectText:)]) {
            [self.delegate pasteboardMonitor:self didDetectText:pasteboard.string];
        }
    }

    // Check for image
    if (pasteboard.hasImages) {
        UIImage *image = pasteboard.image;
        if (image) {
            NSData *imageData = UIImagePNGRepresentation(image);
            if (![imageData isEqualToData:self.lastImageData]) {
                self.lastImageData = imageData;
                if ([self.delegate respondsToSelector:@selector(pasteboardMonitor:didDetectImage:)]) {
                    [self.delegate pasteboardMonitor:self didDetectImage:image];
                }
            }
        }
    }

    // Check for URLs
    if (pasteboard.URLs.count > 0) {
        for (NSURL *url in pasteboard.URLs) {
            if ([self.delegate respondsToSelector:@selector(pasteboardMonitor:didDetectURL:)]) {
                [self.delegate pasteboardMonitor:self didDetectURL:url];
            }
        }
    }
}

@end