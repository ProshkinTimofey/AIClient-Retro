//
//  AIKeychainManager.h
//  AIClient
//
//  Secure storage for API keys and sensitive data using iOS Keychain.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

typedef NS_ENUM(NSUInteger, AIKeychainItemType) {
    AIKeychainItemTypeOpenAIKey = 0,
    AIKeychainItemTypeAnthropicKey,
    AIKeychainItemTypeGeminiKey,
    AIKeychainItemTypeCustomProviderKey,
    AIKeychainItemTypeEncryptionKey
};

@interface AIKeychainManager : NSObject

+ (instancetype)sharedManager;

// Generic key-value storage
- (BOOL)setString:(NSString *)value forKey:(NSString *)key error:(NSError **)error;
- (NSString *)stringForKey:(NSString *)key error:(NSError **)error;
- (BOOL)removeItemForKey:(NSString *)key error:(NSError **)error;

// Provider-specific API keys
- (BOOL)setAPIKey:(NSString *)key forProvider:(AIProviderType)provider error:(NSError **)error;
- (NSString *)apiKeyForProvider:(AIProviderType)provider error:(NSError **)error;
- (BOOL)removeAPIKeyForProvider:(AIProviderType)provider error:(NSError **)error;

// Custom provider keys (identifier-based)
- (BOOL)setCustomProviderKey:(NSString *)key forIdentifier:(NSString *)identifier error:(NSError **)error;
- (NSString *)customProviderKeyForIdentifier:(NSString *)identifier error:(NSError **)error;
- (BOOL)removeCustomProviderKeyForIdentifier:(NSString *)identifier error:(NSError **)error;

// Keychain migration (for app updates)
- (BOOL)migrateFromLegacyKeychain;

// Utility
- (NSArray<NSString *> *)allKeys;
- (void)removeAllKeys error:(NSError **)error;

// Accessibility
- (void)setAccessibility:(CFStringRef)accessibility; // kSecAttrAccessibleWhenUnlockedThisDeviceOnly, etc.
- (CFStringRef)accessibility;

@end