//
//  AIMessageCell.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIMessage.h"

@interface AIMessageCell : UITableViewCell

- (void)configureWithMessage:(AIMessage *)message;

@property (nonatomic, strong) AIMessage *message;

@end