//
//  AIStreamingIndicatorView.m
//  AIClient
//

#import "AIStreamingIndicatorView.h"

@interface AIStreamingIndicatorView ()

@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CGFloat phase;

@end

@implementation AIStreamingIndicatorView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        [self setupGradient];
    }
    return self;
}

- (void)setupGradient {
    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.colors = @[
        (id)[UIColor systemBlueColor].CGColor,
        (id)[UIColor systemPurpleColor].CGColor,
        (id)[UIColor systemPinkColor].CGColor,
        (id)[UIColor systemBlueColor].CGColor,
    ];
    self.gradientLayer.locations = @[@0.0, @0.3, @0.6, @1.0];
    self.gradientLayer.startPoint = CGPointMake(0, 0.5);
    self.gradientLayer.endPoint = CGPointMake(1, 0.5);
    [self.layer addSublayer:self.gradientLayer];

    // Mask to create animated dots
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.fillColor = [UIColor blackColor].CGColor;
    self.gradientLayer.mask = maskLayer;
    self.maskLayer = maskLayer;
}

@property (nonatomic, strong) CAShapeLayer *maskLayer;

- (void)layoutSubviews {
    [super layoutSubviews];
    self.gradientLayer.frame = self.bounds;
    [self updateMask];
}

- (void)updateMask {
    CGFloat dotWidth = 4;
    CGFloat dotSpacing = 8;
    CGFloat totalWidth = self.bounds.size.width;
    CGFloat y = self.bounds.size.height / 2;

    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat x = -self.phase * (dotWidth + dotSpacing);

    while (x < totalWidth + dotWidth) {
        [path appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(x, y - 1, dotWidth, 2) cornerRadius:1]];
        x += dotWidth + dotSpacing;
    }

    self.maskLayer.path = path.CGPath;
}

- (void)startAnimating {
    self.hidden = NO;
    self.phase = 0;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(animationStep)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopAnimating {
    self.hidden = YES;
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)animationStep {
    self.phase += 0.02;
    if (self.phase > 1.0) self.phase = 0;
    [self updateMask];
}

@end