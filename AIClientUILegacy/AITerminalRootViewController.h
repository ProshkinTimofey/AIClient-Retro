//
//  AITerminalRootViewController.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIConversation.h"

@interface AITerminalRootViewController : UITableViewController <AIConversationManagerDelegate>

@property (nonatomic, strong) NSArray<AIConversation *> *conversations;

@end