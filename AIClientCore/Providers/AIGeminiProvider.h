//
//  AIGeminiProvider.h
//  AIClient
//

#import "AIProviderProtocol.h"

@interface AIGeminiProvider : NSObject <AIProviderProtocol>

@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *apiBaseURL;

- (instancetype)initWithAPIKey:(NSString *)apiKey;

@end