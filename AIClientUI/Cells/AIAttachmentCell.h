//
//  AIAttachmentCell.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIAttachment.h"

@protocol AIAttachmentCellDelegate <NSObject>

- (void)attachmentCellDidTapRemove:(id)cell;

@end

@interface AIAttachmentCell : UICollectionViewCell

@property (nonatomic, weak) id<AIAttachmentCellDelegate> delegate;
@property (nonatomic, strong) AIAttachment *attachment;

- (void)configureWithAttachment:(AIAttachment *)attachment;

@end