//
//  AIChatInputView.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIAttachment.h"

@protocol AIChatInputViewDelegate <NSObject>

@optional
- (void)chatInputView:(id)inputView didSendText:(NSString *)text attachments:(NSArray<AIAttachment *> *)attachments;
- (void)chatInputViewDidTapAttach:(id)inputView;
- (void)chatInputViewDidTapImageGen:(id)inputView;
- (void)chatInputViewHeightDidChange:(id)inputView;

@end

@interface AIChatInputView : UIView

@property (nonatomic, weak) id<AIChatInputViewDelegate> delegate;
@property (nonatomic, strong) NSArray<AIAttachment *> *attachments;

- (void)clearInput;

@end