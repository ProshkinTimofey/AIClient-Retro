//
//  AINotificationManager.h
//  AIClient
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

@interface AINotificationManager : NSObject

+ (instancetype)sharedManager;

- (void)requestAuthorizationWithCompletion:(void (^)(BOOL granted, NSError *error))completion;
- (void)scheduleLocalNotificationWithTitle:(NSString *)title body:(NSString *)body identifier:(NSString *)identifier timeInterval:(TimeInterval)interval;
- (void)cancelNotificationWithIdentifier:(NSString *)identifier;
- (void)cancelAllNotifications;
- (void)handleNotificationResponse:(UNNotificationResponse *)response;

@end