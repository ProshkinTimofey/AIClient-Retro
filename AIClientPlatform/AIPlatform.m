//
//  AIPlatform.m
//  AIClient
//

#import "AIPlatform.h"
#import <sys/utsname.h>
#import <Security/Security.h>

static AIPlatform *_sharedPlatform = nil;

@implementation AIPlatform

+ (instancetype)sharedPlatform {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedPlatform = [[self alloc] init];
    });
    return _sharedPlatform;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Detect jailbreak/TrollStore
        _isJailbroken = [self checkJailbreak];
        _isTrollStore = [self checkTrollStore];
    }
    return self;
}

#pragma mark - Device Info

- (NSString *)deviceModel {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

- (NSString *)systemVersion {
    return [UIDevice currentDevice].systemVersion;
}

- (NSString *)appVersion {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

- (NSString *)buildNumber {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
}

- (UIUserInterfaceIdiom)idiom {
    return [UIDevice currentDevice].userInterfaceIdiom;
}

- (BOOL)checkJailbreak {
    // Check for common jailbreak files
    NSArray *paths = @[
        @"/Applications/Cydia.app",
        @"/Library/MobileSubstrate/MobileSubstrate.dylib",
        @"/bin/bash",
        @"/usr/sbin/sshd",
        @"/etc/apt",
        @"/private/var/lib/apt",
    ];
    for (NSString *path in paths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) return YES;
    }
    // Check write access to root
    FILE *f = fopen("/.test_jailbreak", "w");
    if (f) {
        fclose(f);
        remove("/.test_jailbreak");
        return YES;
    }
    return NO;
}

- (BOOL)checkTrollStore {
    // Check for TrollStore specific indicators
    return [[NSFileManager defaultManager] fileExistsAtPath:@"/var/containers/Bundle/Application/.trollstore"];
}

#pragma mark - Haptics

- (void)impactFeedback:(UIImpactFeedbackGeneratorStyle)style {
    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
    [generator prepare];
    [generator impactOccurred];
}

- (void)notificationFeedback:(UINotificationFeedbackType)type {
    UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
    [generator prepare];
    [generator notificationOccurred:type];
}

- (void)selectionFeedback {
    UISelectionFeedbackGenerator *generator = [[UISelectionFeedbackGenerator alloc] init];
    [generator prepare];
    [generator selectionChanged];
}

#pragma mark - Pasteboard

- (void)copyToPasteboard:(NSString *)string {
    [[UIPasteboard generalPasteboard] setString:string];
}

- (NSString *)stringFromPasteboard {
    return [UIPasteboard generalPasteboard].string;
}

- (BOOL)hasImagesInPasteboard {
    return [UIPasteboard generalPasteboard].hasImages;
}

- (UIImage *)imageFromPasteboard {
    return [UIPasteboard generalPasteboard].image;
}

#pragma mark - Files

- (NSString *)documentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
}

- (NSString *)cachesDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
}

- (NSString *)tmpDirectory {
    return NSTemporaryDirectory();
}

- (BOOL)fileExistsAtPath:(NSString *)path {
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (NSDictionary *)fileAttributesAtPath:(NSString *)path error:(NSError **)error {
    return [[NSFileManager defaultManager] attributesOfItemAtPath:path error:error];
}

- (BOOL)removeFileAtPath:(NSString *)path error:(NSError **)error {
    return [[NSFileManager defaultManager] removeItemAtPath:path error:error];
}

- (BOOL)copyFileFromPath:(NSString *)src toPath:(NSString *)dst error:(NSError **)error {
    return [[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:error];
}

#pragma mark - Network

- (BOOL)isNetworkReachable {
    // Simple check - would use NWPathMonitor in production
    return YES;
}

- (BOOL)isWiFiConnected {
    return NO; // Would need Network framework
}

- (BOOL)isCellularConnected {
    return NO; // Would need Network framework
}

#pragma mark - App Lifecycle

- (void)openURL:(NSURL *)url {
    [[UIApplication sharedApplication] openURL:url];
}

- (void)openSettings {
    NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    [self openURL:settingsURL];
}

- (void)requestReview {
    if (@available(iOS 14.0, *)) {
        // SKStoreReviewController requestReviewInScene
    } else {
        // SKStoreReviewController requestReview
    }
}

#pragma mark - Keychain

- (BOOL)saveToKeychain:(NSString *)value forKey:(NSString *)key {
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: @"AIClient",
        (__bridge id)kSecAttrAccount: key,
        (__bridge id)kSecValueData: data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    };

    SecItemDelete((__bridge CFDictionaryRef)query);
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    return status == errSecSuccess;
}

- (NSString *)loadFromKeychainForKey:(NSString *)key {
    NSMutableDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: @"AIClient",
        (__bridge id)kSecAttrAccount: key,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
    };

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecSuccess) {
        NSData *data = (__bridge_transfer NSData *)result;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (BOOL)deleteFromKeychainForKey:(NSString *)key {
    NSMutableDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: @"AIClient",
        (__bridge id)kSecAttrAccount: key,
    };

    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    return status == errSecSuccess || status == errSecItemNotFound;
}

@end