//
//  AITerminalImageGenViewController.h
//  AIClient
//

#import <UIKit/UIKit.h>

@protocol AITerminalImageGenDelegate <NSObject>

@optional
- (void)imageGenViewController:(id)vc didGenerateImages:(NSArray<NSString *> *)urls;

@end

@interface AITerminalImageGenViewController : UIViewController

@property (nonatomic, weak) id<AITerminalImageGenDelegate> delegate;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *promptLabel;
@property (nonatomic, strong) UIView *promptContainer;
@property (nonatomic, strong) UILabel *promptPlaceholder;
@property (nonatomic, strong) UITextView *promptView;
@property (nonatomic, strong) UILabel *modelLabel;
@property (nonatomic, strong) UIPickerView *modelPicker;
@property (nonatomic, strong) UILabel *sizeLabel;
@property (nonatomic, strong) UIPickerView *sizePicker;
@property (nonatomic, strong) UILabel *qualityLabel;
@property (nonatomic, strong) UIPickerView *qualityPicker;
@property (nonatomic, strong) UILabel *countLabelTitle;
@property (nonatomic, strong) UIView *countContainer;
@property (nonatomic, strong) UILabel *countValueLabel;
@property (nonatomic, strong) UIStepper *countStepper;
@property (nonatomic, strong) UIButton *genButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSArray<NSString *> *models;
@property (nonatomic, strong) NSArray *sizes;
@property (nonatomic, strong) NSArray<NSString *> *qualities;
@property (nonatomic, assign) NSInteger modelIdx, sizeIdx, qualityIdx, count;

@end