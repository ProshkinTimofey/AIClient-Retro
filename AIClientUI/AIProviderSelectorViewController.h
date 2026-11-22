//
//  AIProviderSelectorViewController.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIProviderProtocol.h"

@protocol AIProviderSelectorDelegate <NSObject>

- (void)providerSelector:(id)selector didSelectProvider:(AIProviderType)providerType;

@end

@interface AIProviderSelectorViewController : UITableViewController

@property (nonatomic, assign) AIProviderType selectedProviderType;
@property (nonatomic, weak) id<AIProviderSelectorDelegate> delegate;

@end