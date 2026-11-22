//
//  AITerminalImageGenViewController.m
//  AIClient
//
//  Theme-aware image generation with manual layout (no Auto Layout)
//

#import "AITerminalImageGenViewController.h"
#import "AIAPIManager.h"
#import "AIProviderProtocol.h"
#import "AITheme.h"

@implementation AITerminalImageGenViewController {
    id<AITheme> _theme;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = @"Generate Image";
        _modelIdx = _sizeIdx = _qualityIdx = 0;
        _count = 1;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _theme = [[AIThemeManager sharedManager] currentTheme];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(themeDidChange:)
                                                 name:@"AIThemeDidChangeNotification"
                                               object:nil];

    [self applyTheme];
    [self setupViews];
    [self loadOptions];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)themeDidChange:(NSNotification *)note {
    _theme = [[AIThemeManager sharedManager] currentTheme];
    [self applyTheme];
    [self.view setNeedsLayout];
}

- (void)applyTheme {
    _theme = [[AIThemeManager sharedManager] currentTheme];

    self.view.backgroundColor = _theme.backgroundColor;
    [_theme styleNavigationBar:self.navigationController.navigationBar];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"[Cancel]" style:UIBarButtonItemStylePlain target:self action:@selector(cancelTapped)];
    [_theme styleBarButton:self.navigationItem.leftBarButtonItem withTheme:_theme];

    // Re-style all subviews
    [self applyThemeToSubviews:self.view];
}

- (void)applyThemeToSubviews:(UIView *)view {
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            [_theme styleLabel:(UILabel *)sub style:@"monospace"];
        } else if ([sub isKindOfClass:[UITextView class]]) {
            [_theme styleTextView:(UITextView *)sub];
        } else if ([sub isKindOfClass:[UIButton class]]) {
            [_theme styleButton:(UIButton *)sub forState:UIControlStateNormal];
        } else if ([sub isKindOfClass:[UIPickerView class]]) {
            // Picker will be styled via delegate
        } else if ([sub isKindOfClass:[UIStepper class]]) {
            ((UIStepper *)sub).tintColor = _theme.primaryColor;
        } else if ([sub isKindOfClass:[UIActivityIndicatorView class]]) {
            ((UIActivityIndicatorView *)sub).color = _theme.primaryColor;
        } else if ([sub isKindOfClass:[UIView class]]) {
            sub.backgroundColor = _theme.surfaceColor;
            sub.layer.borderColor = _theme.borderColor.CGColor;
            sub.layer.borderWidth = _theme.borderWidth;
            sub.layer.cornerRadius = _theme.useRoundedCorners ? 8 : 0;
            sub.clipsToBounds = YES;
        }
        if (sub.subviews.count > 0) {
            [self applyThemeToSubviews:sub];
        }
    }
}

- (void)setupViews {
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // Scroll view
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.showsVerticalScrollIndicator = YES;
    [self.view addSubview:scroll];
    _scrollView = scroll;

    // Content view
    _contentView = [[UIView alloc] initWithFrame:CGRectZero];
    _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [scroll addSubview:_contentView];

    // Prompt label
    _promptLabel = [self createLabel:@"> prompt"];
    [_contentView addSubview:_promptLabel];

    // Prompt container
    _promptContainer = [[UIView alloc] initWithFrame:CGRectZero];
    _promptContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_contentView addSubview:_promptContainer];

    // Prompt placeholder
    _promptPlaceholder = [[UILabel alloc] initWithFrame:CGRectZero];
    _promptPlaceholder.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    _promptPlaceholder.numberOfLines = 1;
    [_promptContainer addSubview:_promptPlaceholder];

    // Prompt text view
    _promptView = [[UITextView alloc] initWithFrame:CGRectZero];
    _promptView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _promptView.backgroundColor = [UIColor clearColor];
    _promptView.font = [UIFont fontWithName:@"Courier" size:14];
    _promptView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    _promptView.delegate = self;
    _promptView.isScrollEnabled = NO;
    [_promptContainer addSubview:_promptView];

    // Model label
    _modelLabel = [self createLabel:@"> model"];
    [_contentView addSubview:_modelLabel];

    // Model picker
    _modelPicker = [[UIPickerView alloc] initWithFrame:CGRectZero];
    _modelPicker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _modelPicker.dataSource = self;
    _modelPicker.delegate = self;
    [_contentView addSubview:_modelPicker];

    // Size label
    _sizeLabel = [self createLabel:@"> size"];
    [_contentView addSubview:_sizeLabel];

    // Size picker
    _sizePicker = [[UIPickerView alloc] initWithFrame:CGRectZero];
    _sizePicker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _sizePicker.dataSource = self;
    _sizePicker.delegate = self;
    [_contentView addSubview:_sizePicker];

    // Quality label
    _qualityLabel = [self createLabel:@"> quality"];
    [_contentView addSubview:_qualityLabel];

    // Quality picker
    _qualityPicker = [[UIPickerView alloc] initWithFrame:CGRectZero];
    _qualityPicker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _qualityPicker.dataSource = self;
    _qualityPicker.delegate = self;
    [_contentView addSubview:_qualityPicker];

    // Count label
    _countLabelTitle = [self createLabel:@"> count"];
    [_contentView addSubview:_countLabelTitle];

    // Count container
    _countContainer = [[UIView alloc] initWithFrame:CGRectZero];
    _countContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [_contentView addSubview:_countContainer];

    // Count value label
    _countValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _countValueLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    _countValueLabel.textAlignment = NSTextAlignmentCenter;
    _countValueLabel.text = @"1";
    [_countContainer addSubview:_countValueLabel];

    // Stepper
    _countStepper = [[UIStepper alloc] initWithFrame:CGRectZero];
    _countStepper.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    _countStepper.minimumValue = 1;
    _countStepper.maximumValue = 4;
    _countStepper.value = 1;
    [_countStepper addTarget:self action:@selector(countChanged:) forControlEvents:UIControlEventValueChanged];
    [_countContainer addSubview:_countStepper];

    // Generate button
    _genButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _genButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_genButton setTitle:@"GENERATE" forState:UIControlStateNormal];
    _genButton.titleLabel.font = [UIFont fontWithName:@"Courier-Bold" size:16];
    [_genButton addTarget:self action:@selector(genTapped) forControlEvents:UIControlEventTouchUpInside];
    [_contentView addSubview:_genButton];

    // Spinner
    _spinner = [[UIActivityIndicatorView alloc] initWithStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    _spinner.hidesWhenStopped = YES;
    [_contentView addSubview:_spinner];

    // Initial style
    [self applyDefaultStyle];
}

- (UILabel *)createLabel:(NSString *)text {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    l.numberOfLines = 1;
    l.text = text;
    return l;
}

- (void)applyDefaultStyle {
    self.view.backgroundColor = [UIColor blackColor];

    _promptLabel.font = [UIFont fontWithName:@"Courier-Bold" size:13];
    _promptLabel.textColor = [UIColor greenColor];

    _promptContainer.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];
    _promptContainer.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1.0].CGColor;
    _promptContainer.layer.borderWidth = 0.5;

    _promptPlaceholder.font = [UIFont fontWithName:@"Courier" size:14];
    _promptPlaceholder.textColor = [UIColor colorWithWhite:0.4 alpha:1.0];
    _promptPlaceholder.text = @"Describe the image...";

    _promptView.font = [UIFont fontWithName:@"Courier" size:14];
    _promptView.textColor = [UIColor whiteColor];

    _modelLabel.font = [UIFont fontWithName:@"Courier-Bold" size:13];
    _modelLabel.textColor = [UIColor greenColor];

    _sizeLabel.font = [UIFont fontWithName:@"Courier-Bold" size:13];
    _sizeLabel.textColor = [UIColor greenColor];

    _qualityLabel.font = [UIFont fontWithName:@"Courier-Bold" size:13];
    _qualityLabel.textColor = [UIColor greenColor];

    _countLabelTitle.font = [UIFont fontWithName:@"Courier-Bold" size:13];
    _countLabelTitle.textColor = [UIColor greenColor];

    _countValueLabel.font = [UIFont fontWithName:@"Courier-Bold" size:24];
    _countValueLabel.textColor = [UIColor greenColor];

    _countStepper.tintColor = [UIColor greenColor];

    _genButton.titleLabel.font = [UIFont fontWithName:@"Courier-Bold" size:16];
    [_genButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_genButton setTitleColor:[UIColor colorWithWhite:0.5 alpha:1.0] forState:UIControlStateDisabled];
    _genButton.backgroundColor = [UIColor greenColor];
    _genButton.layer.cornerRadius = 4;
    _genButton.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1.0].CGColor;
    _genButton.layer.borderWidth = 1;

    _spinner.color = [UIColor greenColor];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGRect bounds = self.view.bounds;
    UIEdgeInsets insets = UIEdgeInsetsMake(8, 16, 16, 16);
    CGFloat x = insets.left;
    CGFloat y = insets.top;
    CGFloat w = bounds.size.width - insets.left - insets.right;
    CGFloat labelHeight = 16;
    CGFloat spacing = 16;
    CGFloat pickerHeight = 100;
    CGFloat containerHeight = 44;
    CGFloat buttonHeight = 50;

    // Prompt label
    _promptLabel.frame = CGRectMake(x, y, w, labelHeight);
    y += labelHeight + 8;

    // Prompt container
    _promptContainer.frame = CGRectMake(x, y, w, 100);
    _promptPlaceholder.frame = CGRectMake(16, 8, w - 32, 20);
    _promptView.frame = _promptContainer.bounds;
    y += 100 + spacing;

    // Model
    _modelLabel.frame = CGRectMake(x, y, w, labelHeight);
    y += labelHeight + 8;
    _modelPicker.frame = CGRectMake(0, y, bounds.size.width, pickerHeight);
    y += pickerHeight + spacing;

    // Size
    _sizeLabel.frame = CGRectMake(x, y, w, labelHeight);
    y += labelHeight + 8;
    _sizePicker.frame = CGRectMake(0, y, bounds.size.width, pickerHeight);
    y += pickerHeight + spacing;

    // Quality
    _qualityLabel.frame = CGRectMake(x, y, w, labelHeight);
    y += labelHeight + 8;
    _qualityPicker.frame = CGRectMake(0, y, bounds.size.width, pickerHeight);
    y += pickerHeight + spacing;

    // Count
    _countLabelTitle.frame = CGRectMake(x, y, w, labelHeight);
    y += labelHeight + 8;

    _countContainer.frame = CGRectMake(0, y, bounds.size.width, containerHeight);
    _countValueLabel.frame = CGRectMake(bounds.size.width/2 - 60, 0, 60, containerHeight);
    _countStepper.frame = CGRectMake(bounds.size.width/2 + 10, (containerHeight - 29)/2, 94, 29);
    y += containerHeight + spacing;

    // Generate button
    _genButton.frame = CGRectMake(x, y, w, buttonHeight);
    y += buttonHeight + 12;

    // Spinner centered on button
    _spinner.center = CGPointMake(_genButton.center.x, _genButton.center.y);

    // Update content size
    _contentView.frame = CGRectMake(0, 0, bounds.size.width, y + insets.bottom);
    _scrollView.contentSize = _contentView.frame.size;
}

- (void)loadOptions {
    AIAPIManager *api = [AIAPIManager sharedManager];
    self.models = api.currentProvider.availableImageModels.count > 0 ? api.currentProvider.availableImageModels : @[@"dall-e-3", @"dall-e-2", @"imagen-3.0-generate-002"];
    self.sizes = api.supportedImageSizesForModel:self.models.firstObject;
    if (self.sizes.count == 0) self.sizes = @[@(1024), @(1024), @(1792), @(1024), @(1024), @(1792)];
    self.qualities = api.supportedImageQualitiesForModel:self.models.firstObject;
    if (self.qualities.count == 0) self.qualities = @[@"standard", @"hd"];

    [_modelPicker reloadAllComponents];
    [_sizePicker reloadAllComponents];
    [_qualityPicker reloadAllComponents];
}

- (void)cancelTapped {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)countChanged:(UIStepper *)s {
    _count = (NSInteger)s.value;
    _countValueLabel.text = [NSString stringWithFormat:@"%ld", (long)_count];
}

- (void)genTapped {
    NSString *prompt = _promptView.text;
    if (!prompt.length) {
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"> empty" message:@"Enter a prompt" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [_theme styleAlertView:a];
        [a show];
        return;
    }

    NSString *model = self.models[_modelIdx];
    CGSize size = [self.sizes[_sizeIdx * 2] CGSizeValue];
    NSString *quality = self.qualities[_qualityIdx];

    _genButton.enabled = NO;
    _genButton.hidden = YES;
    [_spinner startAnimating];

    [[AIAPIManager sharedManager] generateImageWithPrompt:prompt model:model size:size quality:quality n:_count completion:^(NSArray *urls, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _genButton.enabled = YES;
            _genButton.hidden = NO;
            [_spinner stopAnimating];

            if (err) {
                UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"> failed" message:err.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [_theme styleAlertView:a];
                [a show];
                return;
            }

            if ([self.delegate respondsToSelector:@selector(imageGenViewController:didGenerateImages:)]) {
                [self.delegate imageGenViewController:self didGenerateImages:urls];
            }
            [self.navigationController popViewControllerAnimated:YES];
        });
    }];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)tv {
    _promptPlaceholder.hidden = tv.text.length > 0;
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)p { return 1; }
- (NSInteger)pickerView:(UIPickerView *)p numberOfRowsInComponent:(NSInteger)c {
    if (p == _modelPicker) return self.models.count;
    if (p == _sizePicker) return self.sizes.count / 2;
    if (p == _qualityPicker) return self.qualities.count;
    return 0;
}

#pragma mark - UIPickerViewDelegate

- (UIView *)pickerView:(UIPickerView *)p viewForRow:(NSInteger)r forComponent:(NSInteger)c reusingView:(UIView *)v {
    UILabel *label = (UILabel *)v;
    if (!label) {
        label = [[UILabel alloc] init];
        label.textAlignment = NSTextAlignmentCenter;
    }
    [_theme styleLabel:label style:@"monospace"];

    if (p == _modelPicker) label.text = self.models[r];
    else if (p == _sizePicker) {
        CGSize s = [self.sizes[r * 2] CGSizeValue];
        label.text = [NSString stringWithFormat:@"%.0fx%.0f", s.width, s.height];
    } else if (p == _qualityPicker) label.text = self.qualities[r];
    return label;
}

- (void)pickerView:(UIPickerView *)p didSelectRow:(NSInteger)r inComponent:(NSInteger)c {
    if (p == _modelPicker) { _modelIdx = r; [self loadOptions]; }
    if (p == _sizePicker) _sizeIdx = r;
    if (p == _qualityPicker) _qualityIdx = r;
}

@end