//
//  AIAnthropicProvider.h
//  AIClient
//

#import "AIProviderProtocol.h"

@interface AIAnthropicProvider : NSObject <AIProviderProtocol>

@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *apiBaseURL;
@property (nonatomic, copy) NSString *apiVersion;

- (instancetype)initWithAPIKey:(NSString *)apiKey;

@end