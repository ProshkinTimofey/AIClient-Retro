//
//  AINotificationManager.m
//  AIClient
//

#import "AINotificationManager.h"

static AINotificationManager *_sharedManager = nil;

@implementation AINotificationManager

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[self alloc] init];
    });
    return _sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = self;
    }
    return self;
}

- (void)requestAuthorizationWithCompletion:(void (^)(BOOL granted, NSError *error))completion {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge completionHandler:^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(granted, error);
        });
    }];
}

- (void)scheduleLocalNotificationWithTitle:(NSString *)title body:(NSString *)body identifier:(NSString *)identifier timeInterval:(TimeInterval)interval {
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = title;
    content.body = body;
    content.sound = [UNNotificationSound defaultSound];
    content.badge = @([[UIApplication sharedApplication] applicationIconBadgeNumber] + 1);

    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:interval repeats:NO];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];

    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
}

- (void)cancelNotificationWithIdentifier:(NSString *)identifier {
    [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[identifier]];
}

- (void)cancelAllNotifications {
    [[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
}

- (void)handleNotificationResponse:(UNNotificationResponse *)response {
    // Handle notification tap
    NSString *identifier = response.notification.request.identifier;
    // Navigate to relevant conversation or action
}

@end

// UNUserNotificationCenterDelegate
@implementation AINotificationManager (UNUserNotificationCenterDelegate) <UNUserNotificationCenterDelegate>

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    completionHandler(UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionBadge);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)())completionHandler {
    [self handleNotificationResponse:response];
    completionHandler();
}

@end