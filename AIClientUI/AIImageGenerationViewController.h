//
//  AIImageGenerationViewController.h
//  AIClient
//

#import <UIKit/UIKit.h>

@protocol AIImageGenerationViewControllerDelegate <NSObject>

@optional
- (void)imageGenerationViewController:(id)controller didGenerateImages:(NSArray<NSString *> *)imageURLs;

@end

@interface AIImageGenerationViewController : UIViewController

@property (nonatomic, weak) id<AIImageGenerationViewControllerDelegate> delegate;

@end