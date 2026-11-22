//
//  AITerminalMessageView.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIMessage.h"
#import "AITheme.h"

@interface AITerminalMessageView : UITableViewCell

- (void)configureWithMessage:(AIMessage *)message theme:(id<AITheme>)theme;
+ (CGFloat)heightForMessage:(AIMessage *)message theme:(id<AITheme>)theme width:(CGFloat)width;

@property (nonatomic, strong) AIMessage *message;

@end