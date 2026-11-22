//
//  AITerminalConversationCell.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIConversation.h"
#import "AITheme.h"

@interface AITerminalConversationCell : UITableViewCell

- (void)configureWithConversation:(AIConversation *)conversation index:(NSUInteger)index theme:(id<AITheme>)theme;

@end