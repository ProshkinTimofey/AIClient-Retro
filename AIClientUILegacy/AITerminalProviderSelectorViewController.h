//
//  AITerminalProviderSelectorViewController.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIProviderProtocol.h"

@protocol AITerminalProviderSelectorDelegate <NSObject>

- (void)terminalProviderSelector:(id)sel didSelectProvider:(AIProviderType)type;

@end

@interface AITerminalProviderSelectorViewController : UITableViewController

@property (nonatomic, assign) AIProviderType selectedProviderType;
@property (nonatomic, weak) id<AITerminalProviderSelectorDelegate> delegate;

@end