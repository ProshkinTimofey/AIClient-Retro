//
//  AIAttachmentPickerViewController.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIAttachment.h"

@protocol AIAttachmentPickerViewControllerDelegate <NSObject>

- (void)attachmentPicker:(id)picker didPickAttachments:(NSArray<AIAttachment *> *)attachments;

@end

@interface AIAttachmentPickerViewController : UITableViewController

@property (nonatomic, weak) id<AIAttachmentPickerViewControllerDelegate> delegate;

@end