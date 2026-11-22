//
//  AITerminalStatusBar.h
//  AIClient
//

#import <UIKit/UIKit.h>

@interface AITerminalStatusBar : UIView

@property (nonatomic, strong) UILabel *providerLabel;
@property (nonatomic, strong) UILabel *modelLabel;
@property (nonatomic, strong) UILabel *countLabel;

@end