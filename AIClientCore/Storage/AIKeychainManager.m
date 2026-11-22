//
//  AIKeychainManager.m
//  AIClient
//

#import "AIKeychainManager.h"
#import "AIProviderProtocol.h"

static AIKeychainManager *_sharedManager = nil;
static const NSString *const kServiceName = @"com.ai.client.keys";

@implementation AIKeychainManager

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
        _accessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
    }
    return self;
}

#pragma mark - Generic Key-Value

- (BOOL)setString:(NSString *)value forKey:(NSString *)key error:(NSError **)error {
    if (!value || !key) {
        if (error) *error = [NSError errorWithDomain:@"AIKeychainManager" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid key or value"}];
        return NO;
    }

    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *query = [self baseQueryForKey:key];
    query[(id)kSecValueData] = data;

    // Delete existing
    SecItemDelete((__bridge CFDictionaryRef)query);

    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    if (status != errSecSuccess) {
        if (error) *error = [NSError errorWithDomain:@"AIKeychainManager" code:(NSInteger)status userInfo:@{NSLocalizedDescriptionKey: [self errorMessageForStatus:status]}];
        return NO;
    }
    return YES;
}

- (NSString *)stringForKey:(NSString *)key error:(NSError **)error {
    NSMutableDictionary *query = [self baseQueryForKey:key];
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitOne;
    query[(id)kSecReturnData] = @YES;

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecItemNotFound) {
        return nil;
    }
    if (status != errSecSuccess) {
        if (error) *error = [NSError errorWithDomain:@"AIKeychainManager" code:(NSInteger)status userInfo:@{NSLocalizedDescriptionKey: [self errorMessageForStatus:status]}];
        return nil;
    }

    NSData *data = (__bridge_transfer NSData *)result;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (BOOL)removeItemForKey:(NSString *)key error:(NSError **)error {
    NSMutableDictionary *query = [self baseQueryForKey:key];
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    if (status != errSecSuccess && status != errSecItemNotFound) {
        if (error) *error = [NSError errorWithDomain:@"AIKeychainManager" code:(NSInteger)status userInfo:@{NSLocalizedDescriptionKey: [self errorMessageForStatus:status]}];
        return NO;
    }
    return YES;
}

#pragma mark - Provider API Keys

- (BOOL)setAPIKey:(NSString *)key forProvider:(AIProviderType)provider error:(NSError **)error {
    NSString *keyName = [self keyNameForProvider:provider];
    return [self setString:key forKey:keyName error:error];
}

- (NSString *)apiKeyForProvider:(AIProviderType)provider error:(NSError **)error {
    NSString *keyName = [self keyNameForProvider:provider];
    return [self stringForKey:keyName error:error];
}

- (BOOL)removeAPIKeyForProvider:(AIProviderType)provider error:(NSError **)error {
    NSString *keyName = [self keyNameForProvider:provider];
    return [self removeItemForKey:keyName error:error];
}

#pragma mark - Custom Provider Keys

- (BOOL)setCustomProviderKey:(NSString *)key forIdentifier:(NSString *)identifier error:(NSError **)error {
    NSString *keyName = [NSString stringWithFormat:@"custom_provider_%@", identifier];
    return [self setString:key forKey:keyName error:error];
}

- (NSString *)customProviderKeyForIdentifier:(NSString *)identifier error:(NSError **)error {
    NSString *keyName = [NSString stringWithFormat:@"custom_provider_%@", identifier];
    return [self stringForKey:keyName error:error];
}

- (BOOL)removeCustomProviderKeyForIdentifier:(NSString *)identifier error:(NSError **)error {
    NSString *keyName = [NSString stringWithFormat:@"custom_provider_%@", identifier];
    return [self removeItemForKey:keyName error:error];
}

#pragma mark - Helpers

- (NSMutableDictionary *)baseQueryForKey:(NSString *)key {
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(id)kSecClass] = (id)kSecClassGenericPassword;
    query[(id)kSecAttrService] = kServiceName;
    query[(id)kSecAttrAccount] = key;
    query[(id)kSecAttrAccessible] = _accessibility;
    query[(id)kSecAttrSynchronizable] = @NO;
    return query;
}

- (NSString *)keyNameForProvider:(AIProviderType)provider {
    switch (provider) {
        case AIProviderTypeOpenAI: return @"openai_api_key";
        case AIProviderTypeAnthropic: return @"anthropic_api_key";
        case AIProviderTypeGemini: return @"gemini_api_key";
        case AIProviderTypeCustom: return @"custom_api_key";
        default: return @"unknown_api_key";
    }
}

- (NSString *)errorMessageForStatus:(OSStatus)status {
    switch (status) {
        case errSecItemNotFound: return @"Item not found";
        case errSecDuplicateItem: return @"Duplicate item";
        case errSecAuthFailed: return @"Authentication failed";
        case errSecParam: return @"Invalid parameter";
        case errSecAllocate: return @"Memory allocation failed";
        case errSecNotAvailable: return @"Keychain not available";
        default: return [NSString stringWithFormat:@"Keychain error: %ld", (long)status];
    }
}

#pragma mark - Utilities

- (NSArray<NSString *> *)allKeys {
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(id)kSecClass] = (id)kSecClassGenericPassword;
    query[(id)kSecAttrService] = kServiceName;
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;
    query[(id)kSecReturnAttributes] = @YES;

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess) return @[];

    NSArray *items = (__bridge_transfer NSArray *)result;
    NSMutableArray *keys = [NSMutableArray array];
    for (NSDictionary *item in items) {
        NSString *account = item[(id)kSecAttrAccount];
        if (account) [keys addObject:account];
    }
    return [keys copy];
}

- (void)removeAllKeys error:(NSError **)error {
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(id)kSecClass] = (id)kSecClassGenericPassword;
    query[(id)kSecAttrService] = kServiceName;

    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    if (status != errSecSuccess && status != errSecItemNotFound) {
        if (error) *error = [NSError errorWithDomain:@"AIKeychainManager" code:(NSInteger)status userInfo:@{NSLocalizedDescriptionKey: [self errorMessageForStatus:status]}];
    }
}

- (BOOL)migrateFromLegacyKeychain {
    // For future app updates - migrate from old keychain format
    return YES;
}

@end