//
//  AITerminalAttachmentPickerViewController.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIAttachment.h"

@protocol AITerminalAttachmentPickerDelegate <NSObject>

- (void)attachmentPicker:(id)picker didPickAttachments:(NSArray<AIAttachment *> *)attachments;

@end

@interface AITerminalAttachmentPickerViewController : UITableViewController

@property (nonatomic, weak) id<AITerminalAttachmentPickerDelegate> delegate;

@end