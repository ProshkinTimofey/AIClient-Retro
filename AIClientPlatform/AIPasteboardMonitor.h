//
//  AIPasteboardMonitor.h
//  AIClient
//

#import <Foundation/Foundation.h>

@protocol AIPasteboardMonitorDelegate <NSObject>

@optional
- (void)pasteboardMonitor:(id)monitor didDetectImage:(UIImage *)image;
- (void)pasteboardMonitor:(id)monitor didDetectText:(NSString *)text;
- (void)pasteboardMonitor:(id)monitor didDetectURL:(NSURL *)url;

@end

@interface AIPasteboardMonitor : NSObject

@property (nonatomic, weak) id<AIPasteboardMonitorDelegate> delegate;
@property (nonatomic, assign) BOOL isMonitoring;

+ (instancetype)sharedMonitor;

- (void)startMonitoring;
- (void)stopMonitoring;

@end