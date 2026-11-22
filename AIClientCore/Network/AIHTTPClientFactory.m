//
//  AIHTTPClientFactory.m
//  AIClient
//

#import "AIHTTPClientFactory.h"
#import "AIHTTPClient.h"
#import "AIHTTPClientLegacy.h"

@implementation AIHTTPClientFactory

+ (id<AIHTTPClientProtocol>)createClientWithBaseURL:(NSString *)baseURL {
    if ([self requiresLegacyClient]) {
        return [[AIHTTPClientLegacy alloc] initWithBaseURL:baseURL];
    } else {
        return [[AIHTTPClient alloc] initWithBaseURL:baseURL];
    }
}

+ (BOOL)requiresLegacyClient {
    // iOS 6 and earlier don't have NSURLSession
    // NSFoundationVersionNumber_iOS_6_1 = 893.7
    // NSFoundationVersionNumber_iOS_7_0 = 1063.0
    #if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
        return YES;
    #else
        // Runtime check for deployed version
        return NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_6_1;
    #endif
}

@end

// Make both clients conform to the protocol
@interface AIHTTPClient () <AIHTTPClientProtocol>
@end

@interface AIHTTPClientLegacy () <AIHTTPClientProtocol>
@end