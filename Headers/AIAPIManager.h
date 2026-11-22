//
//  AIAPIManager.h
//  AIClient
//
//  Central manager for API communication, provider management, and conversation handling.
//

#import <Foundation/Foundation.h>
#import "AIProviderProtocol.h"
#import "AIMessage.h"
#import "AIAttachment.h"
#import "AIConversationManager.h"

@protocol AIAPIManagerDelegate <NSObject>

@optional
- (void)apiManager:(id)manager didStartStreamingForMessage:(AIMessage *)message;
- (void)apiManager:(id)manager didReceiveStreamDelta:(NSString *)delta forMessage:(AIMessage *)message;
- (void)apiManager:(id)manager didFinishStreamingForMessage:(AIMessage *)message error:(NSError *)error;
- (void)apiManager:(id)manager didFailToSendMessage:(AIMessage *)message error:(NSError *)error;
- (void)apiManager:(id)manager didGenerateImages:(NSArray<NSString *> *)imageURLs error:(NSError *)error;
- (void)apiManager:(id)manager didUploadAttachment:(AIAttachment *)attachment progress:(float)progress;
- (void)apiManager:(id)manager didFinishUploadingAttachment:(AIAttachment *)attachment error:(NSError *)error;

@end

@interface AIAPIManager : NSObject

@property (nonatomic, weak) id<AIAPIManagerDelegate> delegate;
@property (nonatomic, strong) AIConversationManager *conversationManager;
@property (nonatomic, readonly, strong) id<AIProviderProtocol> currentProvider;
@property (nonatomic, readonly, copy) NSString *currentModel;
@property (nonatomic, readonly, assign) BOOL isStreaming;

// Shared instance
+ (instancetype)sharedManager;

// Provider management
- (void)setProvider:(AIProviderType)type withAPIKey:(NSString *)apiKey completion:(void (^)(BOOL success, NSError *error))completion;
- (void)setCustomProviderWithIdentifier:(NSString *)identifier apiKey:(NSString *)apiKey baseURL:(NSString *)baseURL completion:(void (^)(BOOL success, NSError *error))completion;
- (NSArray<AIProviderType>)availableProviders;
- (BOOL)isProviderConfigured:(AIProviderType)type;

// Chat
- (void)sendMessage:(NSString *)text
         attachments:(NSArray<AIAttachment *> *)attachments
        conversationID:(NSString *)conversationID
           completion:(void (^)(AIMessage *response, NSError *error))completion;

- (void)sendMessage:(AIMessage *)message
       conversationID:(NSString *)conversationID
          completion:(void (^)(AIMessage *response, NSError *error))completion;

// Streaming
- (void)cancelStreaming;
- (void)retryLastMessage;

// Image generation
- (void)generateImageWithPrompt:(NSString *)prompt
                          model:(NSString *)model
                          size:(CGSize)size
                         quality:(NSString *)quality
                          n:(NSInteger)n
                    completion:(void (^)(NSArray<NSString *> *imageURLs, NSError *error))completion;

- (NSArray<NSString *> *)availableImageModels;
- (NSArray<CGSize>)supportedImageSizesForModel:(NSString *)model;
- (NSArray<NSString *> *)supportedImageQualitiesForModel:(NSString *)model;

// Attachments
- (void)uploadAttachment:(AIAttachment *)attachment completion:(void (^)(AIAttachment *attachment, NSError *error))completion;
- (void)uploadAttachments:(NSArray<AIAttachment *> *)attachments completion:(void (^)(NSArray<AIAttachment *> *attachments, NSError *error))completion;

// Model management
- (void)fetchAvailableModelsForCurrentProviderCompletion:(void (^)(NSArray<NSString *> *models, NSError *error))completion;
- (NSArray<NSString *> *)cachedModelsForCurrentProvider;

// Token estimation
- (NSUInteger)estimateTokenCountForMessage:(AIMessage *)message;
- (NSUInteger)estimateTokenCountForConversation:(NSArray<AIMessage *> *)messages;

// Settings
- (void)setSystemPrompt:(NSString *)prompt;
- (NSString *)systemPrompt;
- (void)setTemperature:(float)temperature;
- (float)temperature;
- (void)setMaxTokens:(NSUInteger)maxTokens;
- (NSUInteger)maxTokens;

@end