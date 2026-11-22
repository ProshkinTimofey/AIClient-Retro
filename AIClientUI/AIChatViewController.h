//
//  AIChatViewController.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIConversation.h"

@interface AIChatViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, AIAPIManagerDelegate, AIChatInputViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate>

- (instancetype)initWithConversation:(AIConversation *)conversation;

@end