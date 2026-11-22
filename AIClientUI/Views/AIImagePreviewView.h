//
//  AIImagePreviewView.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIAttachment.h"

@interface AIImagePreviewView : UIView

- (instancetype)initWithAttachment:(AIAttachment *)attachment;

@property (nonatomic, strong) AIAttachment *attachment;

@end