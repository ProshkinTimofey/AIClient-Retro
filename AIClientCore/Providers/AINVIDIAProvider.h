//
//  AINVIDIAProvider.h
//  AIClient
//
//  NVIDIA NIM (NeMo Inference Microservices) Provider
//  API compatible with OpenAI format
//

#import "AIProviderProtocol.h"
#import "AIStreamParser.h"

@interface AINVIDIAProvider : NSObject <AIProviderProtocol>

@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *apiBaseURL;

- (instancetype)initWithAPIKey:(NSString *)apiKey baseURL:(NSString *)baseURL;
- (instancetype)initWithAPIKey:(NSString *)apiKey;

@end