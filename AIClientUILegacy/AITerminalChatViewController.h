//
//  AITerminalChatViewController.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIConversation.h"

@interface AITerminalChatViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, AIAPIManagerDelegate, AITerminalInputViewDelegate, AITerminalAttachmentPickerDelegate>

- (instancetype)initWithConversation:(AIConversation *)conversation;

@end