//
//  AIPlatform.h
//  AIClient
//
//  Platform abstraction layer for iOS-specific functionality.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface AIPlatform : NSObject

+ (instancetype)sharedPlatform;

// Device info
@property (nonatomic, readonly) NSString *deviceModel;
@property (nonatomic, readonly) NSString *systemVersion;
@property (nonatomic, readonly) NSString *appVersion;
@property (nonatomic, readonly) NSString *buildNumber;
@property (nonatomic, readonly) BOOL isJailbroken;
@property (nonatomic, readonly) BOOL isTrollStore;
@property (nonatomic, readonly) UIUserInterfaceIdiom idiom;

// Haptics
- (void)impactFeedback:(UIImpactFeedbackGeneratorStyle)style;
- (void)notificationFeedback:(UINotificationFeedbackType)type;
- (void)selectionFeedback;

// Pasteboard
- (void)copyToPasteboard:(NSString *)string;
- (NSString *)stringFromPasteboard;
- (BOOL)hasImagesInPasteboard;
- (UIImage *)imageFromPasteboard;

// Files
- (NSString *)documentsDirectory;
- (NSString *)cachesDirectory;
- (NSString *)tmpDirectory;
- (BOOL)fileExistsAtPath:(NSString *)path;
- (NSDictionary *)fileAttributesAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)removeFileAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)copyFileFromPath:(NSString *)src toPath:(NSString *)dst error:(NSError **)error;

// Network
- (BOOL)isNetworkReachable;
- (BOOL)isWiFiConnected;
- (BOOL)isCellularConnected;

// App lifecycle
- (void)openURL:(NSURL *)url;
- (void)openSettings;
- (void)requestReview;

// Keychain (convenience)
- (BOOL)saveToKeychain:(NSString *)value forKey:(NSString *)key;
- (NSString *)loadFromKeychainForKey:(NSString *)key;
- (BOOL)deleteFromKeychainForKey:(NSString *)key;

@end