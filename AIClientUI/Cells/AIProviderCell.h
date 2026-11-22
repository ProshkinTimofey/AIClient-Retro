//
//  AIProviderCell.h
//  AIClient
//

#import <UIKit/UIKit.h>
#import "AIProviderProtocol.h"

@interface AIProviderCell : UITableViewCell

- (void)configureWithProviderType:(AIProviderType)type selected:(BOOL)selected configured:(BOOL)configured;

@end