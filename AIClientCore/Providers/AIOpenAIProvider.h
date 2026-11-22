//
//  AIOpenAIProvider.h
//  AIClient
//

#import "AIProviderProtocol.h"
#import "AIStreamParser.h"

@interface AIOpenAIProvider : NSObject <AIProviderProtocol>

@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *organizationID;
@property (nonatomic, copy) NSString *apiBaseURL;
@property (nonatomic, copy) NSString *apiVersion;

- (instancetype)initWithAPIKey:(NSString *)apiKey;

@end