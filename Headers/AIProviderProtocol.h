//
//  AIProviderProtocol.h
//  AIClient
//
//  Protocol defining the interface for AI providers (OpenAI, Anthropic, Gemini).
//

#import <Foundation/Foundation.h>
#import "AIMessage.h"
#import "AIAttachment.h"

@class AIStreamParser;

typedef NS_ENUM(NSUInteger, AIProviderType) {
    AIProviderTypeOpenAI = 0,
    AIProviderTypeAnthropic,
    AIProviderTypeGemini,
    AIProviderTypeNVIDIA,
    AIProviderTypeCustom
};

typedef NS_ENUM(NSUInteger, AIModelCapability) {
    AIModelCapabilityChat = 1 << 0,
    AIModelCapabilityVision = 1 << 1,
    AIModelCapabilityTools = 1 << 2,
    AIModelCapabilityStreaming = 1 << 3,
    AIModelCapabilityImageGeneration = 1 << 4,
    AIModelCapabilityFileUpload = 1 << 5,
};

@protocol AIProviderProtocol <NSObject>

@required

// Provider identification
@property (nonatomic, readonly) AIProviderType providerType;
@property (nonatomic, readonly, copy) NSString *providerName;
@property (nonatomic, readonly, copy) NSString *apiBaseURL;

// Model management
@property (nonatomic, readonly, copy) NSArray<NSString *> *availableChatModels;
@property (nonatomic, readonly, copy) NSArray<NSString *> *availableImageModels;
@property (nonatomic, readonly) NSUInteger modelCapabilities;

// Authentication
- (BOOL)validateAPIKey:(NSString *)apiKey error:(NSError **)error;
- (void)setAPIKey:(NSString *)apiKey;

// Chat completion
- (void)sendMessage:(AIMessage *)message
         attachments:(NSArray<AIAttachment *> *)attachments
        conversation:(NSArray<AIMessage *> *)history
           streamHandler:(void (^)(NSString *delta, BOOL isComplete, NSError *error))handler
           completion:(void (^)(AIMessage *response, NSError *error))completion;

// Image generation
- (void)generateImageWithPrompt:(NSString *)prompt
                          model:(NSString *)model
                          size:(CGSize)size
                         quality:(NSString *)quality
                          n:(NSInteger)n
                    completion:(void (^)(NSArray<NSString *> *imageURLs, NSError *error))completion;

// File upload (for providers supporting file API)
- (void)uploadFile:(AIAttachment *)attachment
        completion:(void (^)(NSString *fileID, NSError *error))completion;

// Streaming support
- (BOOL)supportsStreaming;
- (AIStreamParser *)createStreamParser;

@optional

// Models listing from API
- (void)fetchAvailableModelsWithCompletion:(void (^)(NSArray<NSString *> *models, NSError *error))completion;

// Token counting
- (NSUInteger)estimateTokenCountForMessage:(AIMessage *)message;
- (NSUInteger)estimateTokenCountForText:(NSString *)text;

@end

// Provider factory
@interface AIProviderFactory : NSObject

+ (instancetype)sharedFactory;

- (id<AIProviderProtocol>)createProviderOfType:(AIProviderType)type;
- (id<AIProviderProtocol>)createProviderWithIdentifier:(NSString *)identifier;
- (void)registerProviderClass:(Class)providerClass forType:(AIProviderType)type;
- (NSArray<AIProviderType>)registeredProviderTypes;

@end