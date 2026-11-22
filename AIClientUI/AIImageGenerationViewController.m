//
//  AIImageGenerationViewController.m
//  AIClient
//

#import "AIImageGenerationViewController.h"
#import "AIAPIManager.h"
#import "AIProviderProtocol.h"

@interface AIImageGenerationViewController () <UITextViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate>

@property (nonatomic, strong) UITextView *promptTextView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) UIPickerView *modelPicker;
@property (nonatomic, strong) UIPickerView *sizePicker;
@property (nonatomic, strong) UIPickerView *qualityPicker;
@property (nonatomic, strong) UIStepper *countStepper;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UIButton *generateButton;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UICollectionView *resultsCollectionView;
@property (nonatomic, strong) NSArray<NSString *> *availableModels;
@property (nonatomic, strong) NSArray<CGSize> *availableSizes;
@property (nonatomic, strong) NSArray<NSString *> *availableQualities;
@property (nonatomic, assign) NSInteger selectedModelIndex;
@property (nonatomic, assign) NSInteger selectedSizeIndex;
@property (nonatomic, assign) NSInteger selectedQualityIndex;
@property (nonatomic, assign) NSInteger imageCount;

@end

@implementation AIImageGenerationViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = @"Generate Image";
        _selectedModelIndex = 0;
        _selectedSizeIndex = 0;
        _selectedQualityIndex = 0;
        _imageCount = 1;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelTapped)];

    [self setupViews];
    [self loadOptions];
}

- (void)setupViews {
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:scrollView];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:contentView];

    [NSLayoutConstraint activateConstraints:@[
        contentView.topAnchor.constraintEqualToAnchor:scrollView.topAnchor,
        contentView.leadingAnchor.constraintEqualToAnchor:scrollView.leadingAnchor,
        contentView.trailingAnchor.constraintEqualToAnchor:scrollView.trailingAnchor,
        contentView.bottomAnchor.constraintEqualToAnchor:scrollView.bottomAnchor,
        contentView.widthAnchor.constraintEqualToAnchor:scrollView.widthAnchor,
    ]];

    // Prompt section
    UILabel *promptLabel = [self sectionLabel:@"Prompt"];
    [contentView addSubview:promptLabel];

    UIView *promptContainer = [[UIView alloc] init];
    promptContainer.translatesAutoresizingMaskIntoConstraints = NO;
    promptContainer.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    promptContainer.layer.cornerRadius = 12;
    [contentView addSubview:promptContainer];

    self.placeholderLabel = [[UILabel alloc] init];
    self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeholderLabel.text = @"Describe the image you want to generate...";
    self.placeholderLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.placeholderLabel.textColor = [UIColor tertiaryLabel];
    self.placeholderLabel.numberOfLines = 0;
    [promptContainer addSubview:self.placeholderLabel];

    self.promptTextView = [[UITextView alloc] init];
    self.promptTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.promptTextView.backgroundColor = [UIColor clearColor];
    self.promptTextView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.promptTextView.textColor = [UIColor label];
    self.promptTextView.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);
    self.promptTextView.delegate = self;
    [promptContainer addSubview:self.promptTextView];

    // Model picker
    UILabel *modelLabel = [self sectionLabel:@"Model"];
    [contentView addSubview:modelLabel];

    self.modelPicker = [[UIPickerView alloc] init];
    self.modelPicker.translatesAutoresizingMaskIntoConstraints = NO;
    self.modelPicker.dataSource = self;
    self.modelPicker.delegate = self;
    [contentView addSubview:self.modelPicker];

    // Size picker
    UILabel *sizeLabel = [self sectionLabel:@"Size"];
    [contentView addSubview:sizeLabel];

    self.sizePicker = [[UIPickerView alloc] init];
    self.sizePicker.translatesAutoresizingMaskIntoConstraints = NO;
    self.sizePicker.dataSource = self;
    self.sizePicker.delegate = self;
    [contentView addSubview:self.sizePicker];

    // Quality picker
    UILabel *qualityLabel = [self sectionLabel:@"Quality"];
    [contentView addSubview:qualityLabel];

    self.qualityPicker = [[UIPickerView alloc] init];
    self.qualityPicker.translatesAutoresizingMaskIntoConstraints = NO;
    self.qualityPicker.dataSource = self;
    self.qualityPicker.delegate = self;
    [contentView addSubview:self.qualityPicker];

    // Count stepper
    UILabel *countLabel = [self sectionLabel:@"Number of Images"];
    [contentView addSubview:countLabel];

    UIView *countContainer = [[UIView alloc] init];
    countContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:countContainer];

    self.countStepper = [[UIStepper alloc] init];
    self.countStepper.translatesAutoresizingMaskIntoConstraints = NO;
    self.countStepper.minimumValue = 1;
    self.countStepper.maximumValue = 4;
    self.countStepper.value = 1;
    self.countStepper.stepValue = 1;
    [self.countStepper addTarget:self action:@selector(countChanged:) forControlEvents:UIControlEventValueChanged];
    [countContainer addSubview:self.countStepper];

    self.countLabel = [[UILabel alloc] init];
    self.countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.countLabel.text = @"1";
    self.countLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
    self.countLabel.textAlignment = NSTextAlignmentCenter;
    [countContainer addSubview:self.countLabel];

    // Generate button
    self.generateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.generateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.generateButton.setTitle:@"Generate", forState:UIControlStateNormal];
    self.generateButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.generateButton.backgroundColor = [UIColor systemBlueColor];
    self.generateButton.tintColor = [UIColor whiteColor];
    self.generateButton.layer.cornerRadius = 12;
    [self.generateButton addTarget:self action:@selector(generateTapped) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:self.generateButton];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.hidesWhenStopped = YES;
    [contentView addSubview:self.loadingIndicator];

    // Results
    UILabel *resultsLabel = [self sectionLabel:@"Results"];
    [contentView addSubview:resultsLabel];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.itemSize = CGSizeMake((self.view.bounds.size.width - 48) / 2, (self.view.bounds.size.width - 48) / 2 + 40);
    layout.minimumInteritemSpacing = 12;
    layout.minimumLineSpacing = 12;
    layout.sectionInset = UIEdgeInsetsMake(0, 12, 12, 12);

    self.resultsCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.resultsCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultsCollectionView.backgroundColor = [UIColor clearColor];
    self.resultsCollectionView.dataSource = self;
    self.resultsCollectionView.delegate = self;
    self.resultsCollectionView.registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"ResultCell"];
    [contentView addSubview:self.resultsCollectionView];

    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        promptLabel.topAnchor.constraintEqualToAnchor:contentView.topAnchor constant:16],
        promptLabel.leadingAnchor.constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        promptLabel.trailingAnchor.constraintEqualToAnchor:contentView.trailingAnchor constant:-16],

        promptContainer.topAnchor.constraintEqualToAnchor:promptLabel.bottomAnchor constant:8],
        promptContainer.leadingAnchor.constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        promptContainer.trailingAnchor.constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
        promptContainer.heightAnchor.constraintEqualToConstant(100)],

        self.placeholderLabel.topAnchor.constraintEqualToAnchor:promptContainer.topAnchor constant:12],
        self.placeholderLabel.leadingAnchor.constraintEqualToAnchor:promptContainer.leadingAnchor constant:16],
        self.placeholderLabel.trailingAnchor.constraintEqualToAnchor:promptContainer.trailingAnchor constant:-16],

        self.promptTextView.topAnchor.constraintEqualToAnchor:promptContainer.topAnchor],
        self.promptTextView.leadingAnchor.constraintEqualToAnchor:promptContainer.leadingAnchor],
        self.promptTextView.trailingAnchor.constraintEqualToAnchor:promptContainer.trailingAnchor],
        self.promptTextView.bottomAnchor.constraintEqualToAnchor:promptContainer.bottomAnchor],

        modelLabel.topAnchor.constraintEqualToAnchor:promptContainer.bottomAnchor constant:20],
        modelLabel.leadingAnchor.constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        modelLabel.trailingAnchor.constraintEqualToAnchor:contentView.trailingAnchor constant:-16],

        self.modelPicker.topAnchor.constraintEqualToAnchor:modelLabel.bottomAnchor constant:8],
        self.modelPicker.leadingAnchor.constraintEqualToAnchor:contentView.leadingAnchor],
        self.modelPicker.trailingAnchor.constraintEqualToAnchor:contentView.trailingAnchor],
        self.modelPicker.heightAnchor.constraintEqualToConstant(100)],

        sizeLabel.topAnchor.constraintEqualToAnchor:self.modelPicker.bottomAnchor constant:20],
        sizeLabel.leadingAnchor.constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        sizeLabel.trailingAnchor.constraintEqualToAnchor:contentView.trailingAnchor constant:-16],

        self.sizePicker.topAnchor.constraintEqualToAnchor:sizeLabel.bottomAnchor constant:8],
        self.sizePicker.leadingAnchor.constraintEqualToAnchor:contentView.leadingAnchor],
        self.sizePicker.trailingAnchor.constraintEqualToAnchor:contentView.trailingAnchor],
        self.sizePicker.heightAnchor.constraintEqualToConstant(100)],

        qualityLabel.topAnchor.constraintEqualToAnchor:self.sizePicker.bottomAnchor constant:20],
        qualityLabel.leadingAnchor.constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        qualityLabel.trailingAnchor.constraintEqualToAnchor:contentView.trailingAnchor constant:-16],

        self.qualityPicker.topAnchor.constraintEqualToAnchor:qualityLabel.bottomAnchor constant:8],
        self.qualityPicker.leadingAnchor.constraintEqualToAnchor:contentView.leadingAnchor],
        self.qualityPicker.trailingAnchor.constraintEqualToAnchor:contentView.trailingAnchor],
        self.qualityPicker.heightAnchor.constraintEqualToConstant(100)],

        countLabel.topAnchor.constraintEqualToAnchor:self.qualityPicker.bottomAnchor constant:20],
        countLabel.leadingAnchor.constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        countLabel.trailingAnchor.constraintEqualToAnchor:contentView.trailingAnchor constant:-16],

        countContainer.topAnchor.constraintEqualToAnchor:countLabel.bottomAnchor constant:8],
        countContainer.centerXAnchor.constraintEqualToAnchor:contentView.centerXAnchor],

        self.countLabel.centerYAnchor.constraintEqualToAnchor:countContainer.centerYAnchor],
        self.countLabel.widthAnchor.constraintEqualToConstant(60)],

        self.countStepper.centerYAnchor.constraintEqualToAnchor:countContainer.centerYAnchor],
        self.countStepper.leadingAnchor.constraintEqualToAnchor:self.countLabel.trailingAnchor constant:16],
        countContainer.trailingAnchor.constraintEqualToAnchor:self.countStepper.trailingAnchor],
        countContainer.heightAnchor.constraintEqualToConstant(44)],

        self.generateButton.topAnchor.constraintEqualToAnchor:countContainer.bottomAnchor constant:24],
        self.generateButton.leadingAnchor.constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        self.generateButton.trailingAnchor.constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
        self.generateButton.heightAnchor.constraintEqualToConstant(50)],

        self.loadingIndicator.centerXAnchor.constraintEqualToAnchor:self.generateButton.centerXAnchor],
        self.loadingIndicator.centerYAnchor.constraintEqualToAnchor:self.generateButton.centerYAnchor],

        resultsLabel.topAnchor.constraintEqualToAnchor:self.generateButton.bottomAnchor constant:24],
        resultsLabel.leadingAnchor.constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        resultsLabel.trailingAnchor.constraintEqualToAnchor:contentView.trailingAnchor constant:-16],

        self.resultsCollectionView.topAnchor.constraintEqualToAnchor:resultsLabel.bottomAnchor constant:8],
        self.resultsCollectionView.leadingAnchor.constraintEqualToAnchor:contentView.leadingAnchor],
        self.resultsCollectionView.trailingAnchor.constraintEqualToAnchor:contentView.trailingAnchor],
        self.resultsCollectionView.bottomAnchor.constraintEqualToAnchor:contentView.bottomAnchor constant:-16],
        self.resultsCollectionView.heightAnchor.constraintEqualToConstant(300),
    ]];
}

- (UILabel *)sectionLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    label.textColor = [UIColor label];
    return label;
}

- (void)loadOptions {
    AIAPIManager *apiManager = [AIAPIManager sharedManager];
    self.availableModels = apiManager.currentProvider.availableImageModels;
    if (self.availableModels.count == 0) {
        self.availableModels = @[@"dall-e-3", @"dall-e-2", @"imagen-3.0-generate-002"];
    }

    self.availableSizes = apiManager.supportedImageSizesForModel:self.availableModels.firstObject;
    if (self.availableSizes.count == 0) {
        self.availableSizes = @[@(1024), @(1024), @(1792), @(1024), @(1024), @(1792)];
    }

    self.availableQualities = apiManager.supportedImageQualitiesForModel:self.availableModels.firstObject;
    if (self.availableQualities.count == 0) {
        self.availableQualities = @[@"standard", @"hd"];
    }

    [self.modelPicker reloadAllComponents];
    [self.sizePicker reloadAllComponents];
    [self.qualityPicker reloadAllComponents];
}

#pragma mark - Actions

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)countChanged:(UIStepper *)stepper {
    self.imageCount = (NSInteger)stepper.value;
    self.countLabel.text = [NSString stringWithFormat:@"%ld", (long)self.imageCount];
}

- (void)generateTapped {
    NSString *prompt = self.promptTextView.text;
    if (!prompt || prompt.length == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Empty Prompt" message:@"Please enter a description for the image." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    NSString *model = self.availableModels.count > 0 ? self.availableModels[self.selectedModelIndex] : nil;
    CGSize size = self.availableSizes.count > 0 ? self.availableSizes[self.selectedSizeIndex] : CGSizeMake(1024, 1024);
    NSString *quality = self.availableQualities.count > 0 ? self.availableQualities[self.selectedQualityIndex] : @"standard";

    self.generateButton.enabled = NO;
    self.generateButton.hidden = YES;
    [self.loadingIndicator startAnimating];

    [[AIAPIManager sharedManager] generateImageWithPrompt:prompt
                                                      model:model
                                                      size:size
                                                     quality:quality
                                                      n:self.imageCount
                                            completion:^(NSArray<NSString *> *imageURLs, NSError *error) {
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    self.generateButton.enabled = YES;
                                                    self.generateButton.hidden = NO;
                                                    [self.loadingIndicator stopAnimating];

                                                    if (error) {
                                                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Generation Failed" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                                                        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                                                        [self presentViewController:alert animated:YES completion:nil];
                                                        return;
                                                    }

                                                    if ([self.delegate respondsToSelector:@selector(imageGenerationViewController:didGenerateImages:)]) {
                                                        [self.delegate imageGenerationViewController:self didGenerateImages:imageURLs];
                                                    }

                                                    [self dismissViewControllerAnimated:YES completion:nil];
                                                });
                                            }];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    self.placeholderLabel.hidden = textView.text.length > 0;
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if (pickerView == self.modelPicker) return self.availableModels.count;
    if (pickerView == self.sizePicker) return self.availableSizes.count / 2; // width/height pairs
    if (pickerView == self.qualityPicker) return self.availableQualities.count;
    return 0;
}

#pragma mark - UIPickerViewDelegate

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (pickerView == self.modelPicker) return self.availableModels[row];
    if (pickerView == self.sizePicker) {
        CGSize size = self.availableSizes[row * 2];
        return [NSString stringWithFormat:@"%.0fx%.0f", size.width, size.height];
    }
    if (pickerView == self.qualityPicker) return self.availableQualities[row];
    return nil;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    if (pickerView == self.modelPicker) self.selectedModelIndex = row;
    if (pickerView == self.sizePicker) self.selectedSizeIndex = row;
    if (pickerView == self.qualityPicker) self.selectedQualityIndex = row;

    // Reload sizes/qualities when model changes
    if (pickerView == self.modelPicker) {
        [self loadOptions];
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return 0; // Results shown after generation
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [collectionView dequeueReusableCellWithReuseIdentifier:@"ResultCell" forIndexPath:indexPath];
}

@end