//
//  AITerminalInputView.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIAttachment.h"
#import "AITheme.h"

extern NSString *const AITerminalInputViewHeightDidChangeNotification;

@protocol AITerminalInputViewDelegate <NSObject>

@optional
- (void)terminalInputView:(id)iv didSendText:(NSString *)text attachments:(NSArray<AIAttachment *> *)attachments;
- (void)terminalInputViewDidTapAttach:(id)iv;
- (void)terminalInputViewDidTapImageGen:(id)iv;
- (void)terminalInputViewHeightDidChange:(id)iv;

@end

@interface AITerminalInputView : UIView

@property (nonatomic, weak) id<AITerminalInputViewDelegate> delegate;
@property (nonatomic, strong) NSArray<AIAttachment *> *attachments;

- (void)clearInput;
- (void)applyTheme:(id<AITheme>)theme;

@end