//
//  AIRootViewController.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIConversation.h"

@interface AIRootViewController : UITableViewController <UISearchResultsUpdating, AIConversationManagerDelegate>

@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSArray<AIConversation *> *filteredConversations;
@property (nonatomic, assign) BOOL isSearching;

@end