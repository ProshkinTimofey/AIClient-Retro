//
//  AIAPIManager.m
//  AIClient
//

#import "AIAPIManager.h"
#import "AIProviderProtocol.h"
#import "AIProviderFactory.h"
#import "AIOpenAIProvider.h"
#import "AIAnthropicProvider.h"
#import "AIGeminiProvider.h"
#import "AIConversationManager.h"
#import "AIKeychainManager.h"
#import "AIAttachment.h"

@interface AIAPIManager ()

@property (nonatomic, strong) id<AIProviderProtocol> currentProvider;
@property (nonatomic, copy) NSString *currentModel;
@property (nonatomic, assign) BOOL isStreaming;
@property (nonatomic, copy) NSString *systemPrompt;
@property (nonatomic, assign) float temperature;
@property (nonatomic, assign) NSUInteger maxTokens;
@property (nonatomic, strong) AIMessage *streamingMessage;
@property (nonatomic, strong) NSMutableString *streamingBuffer;

@end

@implementation AIAPIManager

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    static AIAPIManager *shared = nil;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _conversationManager = [AIConversationManager sharedManager];
        _temperature = 0.7;
        _maxTokens = 4096;
        _systemPrompt = @"You are a helpful AI assistant.";
        [self loadSavedProvider];
    }
    return self;
}

- (void)loadSavedProvider {
    // Try to load last used provider from UserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger providerType = [defaults integerForKey:@"lastProviderType"];
    if (providerType > 0) {
        NSString *apiKey = [[AIKeychainManager sharedManager] apiKeyForProvider:providerType error:nil];
        if (apiKey) {
            [self setProvider:providerType withAPIKey:apiKey completion:nil];
        }
    }
}

#pragma mark - Provider Management

- (void)setProvider:(AIProviderType)type withAPIKey:(NSString *)apiKey completion:(void (^)(BOOL, NSError *))completion {
    id<AIProviderProtocol> provider = [[AIProviderFactory sharedFactory] createProviderOfType:type];
    if (!provider) {
        if (completion) completion(NO, [NSError errorWithDomain:@"AIAPIManager" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Unknown provider type"}]);
        return;
    }

    NSError *validationError;
    if (![provider validateAPIKey:apiKey error:&validationError]) {
        if (completion) completion(NO, validationError);
        return;
    }

    [provider setAPIKey:apiKey];

    // Save to keychain
    [[AIKeychainManager sharedManager] setAPIKey:apiKey forProvider:type error:nil];

    // Save as last used
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:type forKey:@"lastProviderType"];
    [defaults synchronize];

    _currentProvider = provider;
    _currentModel = provider.availableChatModels.firstObject;

    if (completion) completion(YES, nil);
}

- (void)setCustomProviderWithIdentifier:(NSString *)identifier apiKey:(NSString *)apiKey baseURL:(NSString *)baseURL completion:(void (^)(BOOL, NSError *))completion {
    // For custom OpenAI-compatible endpoints
    AIOpenAIProvider *provider = [[AIOpenAIProvider alloc] initWithAPIKey:apiKey];
    provider.apiBaseURL = baseURL ?: @"https://api.openai.com/v1";

    NSError *validationError;
    if (![provider validateAPIKey:apiKey error:&validationError]) {
        if (completion) completion(NO, validationError);
        return;
    }

    [[AIKeychainManager sharedManager] setCustomProviderKey:apiKey forIdentifier:identifier error:nil];

    _currentProvider = provider;
    _currentModel = provider.availableChatModels.firstObject;

    if (completion) completion(YES, nil);
}

- (NSArray<AIProviderType>)availableProviders {
    return [[AIProviderFactory sharedFactory] registeredProviderTypes];
}

- (BOOL)isProviderConfigured:(AIProviderType)type {
    NSString *key = [[AIKeychainManager sharedManager] apiKeyForProvider:type error:nil];
    return key.length > 0;
}

#pragma mark - Chat

- (void)sendMessage:(NSString *)text
         attachments:(NSArray<AIAttachment *> *)attachments
        conversationID:(NSString *)conversationID
           completion:(void (^)(AIMessage *response, NSError *error))completion {

    AIConversation *conversation = [self.conversationManager loadConversationWithID:conversationID error:nil];
    if (!conversation) {
        conversation = [self.conversationManager createNewConversationWithTitle:@"New Chat"];
    }

    AIMessage *userMessage = [AIMessage userMessage:text attachments:attachments];
    userMessage.model = _currentModel;
    userMessage.status = AIMessageStatusSending;

    [self.conversationManager addMessage:userMessage toConversation:conversation];

    [self sendMessage:userMessage conversationID:conversation.conversationID completion:completion];
}

- (void)sendMessage:(AIMessage *)message
       conversationID:(NSString *)conversationID
          completion:(void (^)(AIMessage *response, NSError *error))completion {

    if (!_currentProvider) {
        if (completion) completion(nil, [NSError errorWithDomain:@"AIAPIManager" code:1 userInfo:@{NSLocalizedDescriptionKey: @"No provider configured"}]);
        return;
    }

    AIConversation *conversation = [self.conversationManager loadConversationWithID:conversationID error:nil];
    if (!conversation) {
        if (completion) completion(nil, [NSError errorWithDomain:@"AIAPIManager" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Conversation not found"}]);
        return;
    }

    message.model = _currentModel;
    message.status = AIMessageStatusSending;

    // Get recent messages for context
    NSArray<AIMessage *> *history = [self.conversationManager recentMessagesForConversation:conversation limit:20];

    _isStreaming = YES;
    _streamingMessage = [[AIMessage alloc] initWithRole:AIMessageRoleAssistant content:@""];
    _streamingMessage.model = _currentModel;
    _streamingMessage.status = AIMessageStatusStreaming;
    _streamingBuffer = [NSMutableString string];

    if ([_delegate respondsToSelector:@selector(apiManager:didStartStreamingForMessage:)]) {
        [_delegate apiManager:self didStartStreamingForMessage:_streamingMessage];
    }

    [_currentProvider sendMessage:message
                         attachments:message.attachments
                        conversation:history
                           streamHandler:^(NSString *delta, BOOL isComplete, NSError *error) {
                               if (error) {
                                   _isStreaming = NO;
                                   message.status = AIMessageStatusFailed;
                                   message.errorMessage = error.localizedDescription;
                                   [self.conversationManager updateMessage:message inConversation:conversation];

                                   if ([_delegate respondsToSelector:@selector(apiManager:didFinishStreamingForMessage:error:)]) {
                                       [_delegate apiManager:self didFinishStreamingForMessage:_streamingMessage error:error];
                                   }
                                   if (completion) completion(nil, error);
                                   return;
                               }

                               if (delta.length > 0) {
                                   [_streamingBuffer appendString:delta];
                                   _streamingMessage.content = _streamingBuffer;

                                   if ([_delegate respondsToSelector:@selector(apiManager:didReceiveStreamDelta:forMessage:)]) {
                                       [_delegate apiManager:self didReceiveStreamDelta:delta forMessage:_streamingMessage];
                                   }
                               }

                               if (isComplete) {
                                   _isStreaming = NO;
                                   _streamingMessage.status = AIMessageStatusComplete;
                                   _streamingMessage.tokenCount = _streamingBuffer.length / 4; // Rough estimate

                                   [self.conversationManager addMessage:_streamingMessage toConversation:conversation];

                                   if ([_delegate respondsToSelector:@selector(apiManager:didFinishStreamingForMessage:error:)]) {
                                       [_delegate apiManager:self didFinishStreamingForMessage:_streamingMessage error:nil];
                                   }
                                   if (completion) completion(_streamingMessage, nil);
                               }
                           }
                           completion:^(AIMessage *response, NSError *error) {
                               // Non-streaming fallback (handled by stream handler for streaming)
                               if (!_isStreaming && error) {
                                   message.status = AIMessageStatusFailed;
                                   message.errorMessage = error.localizedDescription;
                                   [self.conversationManager updateMessage:message inConversation:conversation];

                                   if ([_delegate respondsToSelector:@selector(apiManager:didFailToSendMessage:error:)]) {
                                       [_delegate apiManager:self didFailToSendMessage:message error:error];
                                   }
                                   if (completion) completion(nil, error);
                               } else if (!_isStreaming && response) {
                                   [self.conversationManager addMessage:response toConversation:conversation];
                                   if (completion) completion(response, nil);
                               }
                           }];
}

#pragma mark - Streaming Control

- (void)cancelStreaming {
    if (_isStreaming) {
        _isStreaming = NO;
        if (_streamingMessage) {
            _streamingMessage.status = AIMessageStatusCancelled;
        }
    }
}

- (void)retryLastMessage {
    AIConversation *conversation = self.conversationManager.currentConversation;
    if (!conversation) return;

    AIMessage *lastUserMessage = [conversation lastUserMessage];
    if (!lastUserMessage) return;

    // Remove the failed/assistant response
    AIMessage *lastMessage = [conversation lastMessage];
    if (lastMessage && lastMessage.role == AIMessageRoleAssistant) {
        [self.conversationManager removeMessage:lastMessage fromConversation:conversation];
    }

    // Retry
    [self sendMessage:lastUserMessage conversationID:conversation.conversationID completion:nil];
}

#pragma mark - Image Generation

- (void)generateImageWithPrompt:(NSString *)prompt
                          model:(NSString *)model
                          size:(CGSize)size
                         quality:(NSString *)quality
                          n:(NSInteger)n
                    completion:(void (^)(NSArray<NSString *> *imageURLs, NSError *error))completion {

    if (!_currentProvider) {
        if (completion) completion(nil, [NSError errorWithDomain:@"AIAPIManager" code:1 userInfo:@{NSLocalizedDescriptionKey: @"No provider configured"}]);
        return;
    }

    if (!(_currentProvider.modelCapabilities & AIModelCapabilityImageGeneration)) {
        if (completion) completion(nil, [NSError errorWithDomain:@"AIAPIManager" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Current provider does not support image generation"}]);
        return;
    }

    [_currentProvider generateImageWithPrompt:prompt
                                        model:model ?: _currentModel
                                        size:size
                                       quality:quality
                                        n:n
                              completion:^(NSArray<NSString *> *imageURLs, NSError *error) {
                                  if ([_delegate respondsToSelector:@selector(apiManager:didGenerateImages:error:)]) {
                                      [_delegate apiManager:self didGenerateImages:imageURLs error:error];
                                  }
                                  if (completion) completion(imageURLs, error);
                              }];
}

- (NSArray<NSString *> *)availableImageModels {
    return _currentProvider ? _currentProvider.availableImageModels : @[];
}

- (NSArray<CGSize>)supportedImageSizesForModel:(NSString *)model {
    if ([model hasPrefix:@"dall-e-3"]) {
        return @[@(1024), @(1024), @(1792), @(1024), @(1024), @(1792)];
    } else if ([model hasPrefix:@"dall-e-2"]) {
        return @[@(256), @(256), @(512), @(512), @(1024), @(1024)];
    } else if ([model hasPrefix:@"imagen"]) {
        return @[@(1024), @(1024), @(2048), @(2048)];
    }
    return @[@(1024), @(1024)];
}

- (NSArray<NSString *> *)supportedImageQualitiesForModel:(NSString *)model {
    if ([model hasPrefix:@"dall-e-3"]) {
        return @[@"standard", @"hd"];
    }
    return @[@"standard"];
}

#pragma mark - Attachments

- (void)uploadAttachment:(AIAttachment *)attachment completion:(void (^)(AIAttachment *attachment, NSError *error))completion {
    if (!_currentProvider) {
        if (completion) completion(nil, [NSError errorWithDomain:@"AIAPIManager" code:1 userInfo:@{NSLocalizedDescriptionKey: @"No provider configured"}]);
        return;
    }

    if (!(_currentProvider.modelCapabilities & AIModelCapabilityFileUpload)) {
        if (completion) completion(nil, [NSError errorWithDomain:@"AIAPIManager" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Current provider does not support file upload"}]);
        return;
    }

    attachment.isUploading = YES;
    attachment.uploadProgress = 0.0f;

    if ([_delegate respondsToSelector:@selector(apiManager:didUploadAttachment:progress:)]) {
        [_delegate apiManager:self didUploadAttachment:attachment progress:0.0f];
    }

    [_currentProvider uploadFile:attachment completion:^(NSString *fileID, NSError *error) {
        attachment.isUploading = NO;

        if (error) {
            attachment.uploadError = error.localizedDescription;
            if ([_delegate respondsToSelector:@selector(apiManager:didFinishUploadingAttachment:error:)]) {
                [_delegate apiManager:self didFinishUploadingAttachment:attachment error:error];
            }
            if (completion) completion(attachment, error);
            return;
        }

        attachment.providerFileID = fileID;
        attachment.providerType = _currentProvider.providerName.lowercaseString;
        attachment.isUploaded = YES;
        attachment.uploadProgress = 1.0f;

        if ([_delegate respondsToSelector:@selector(apiManager:didFinishUploadingAttachment:error:)]) {
            [_delegate apiManager:self didFinishUploadingAttachment:attachment error:nil];
        }
        if (completion) completion(attachment, nil);
    }];
}

- (void)uploadAttachments:(NSArray<AIAttachment *> *)attachments completion:(void (^)(NSArray<AIAttachment *> *attachments, NSError *error))completion {
    NSMutableArray *results = [NSMutableArray array];
    NSUInteger completed = 0;
    NSError *firstError = nil;

    for (AIAttachment *att in attachments) {
        [self uploadAttachment:att completion:^(AIAttachment *uploaded, NSError *error) {
            [results addObject:uploaded];
            if (error && !firstError) firstError = error;

            completed++;
            if (completed == attachments.count) {
                if (completion) completion(results, firstError);
            }
        }];
    }
}

#pragma mark - Model Management

- (void)fetchAvailableModelsForCurrentProviderCompletion:(void (^)(NSArray<NSString *> *models, NSError *error))completion {
    if (![_currentProvider respondsToSelector:@selector(fetchAvailableModelsWithCompletion:)]) {
        if (completion) completion(_currentProvider.availableChatModels, nil);
        return;
    }

    [_currentProvider fetchAvailableModelsWithCompletion:completion];
}

- (NSArray<NSString *> *)cachedModelsForCurrentProvider {
    return _currentProvider ? _currentProvider.availableChatModels : @[];
}

#pragma mark - Token Estimation

- (NSUInteger)estimateTokenCountForMessage:(AIMessage *)message {
    // Rough estimation: ~4 characters per token for English
    NSUInteger count = message.content.length / 4;
    for (AIAttachment *att in message.attachments) {
        if (att.type == AIAttachmentTypeImage) {
            count += 85; // Base tokens per image (varies by provider)
        } else {
            count += 100; // Document estimate
        }
    }
    return count;
}

- (NSUInteger)estimateTokenCountForConversation:(NSArray<AIMessage *> *)messages {
    NSUInteger total = 0;
    for (AIMessage *msg in messages) {
        total += [self estimateTokenCountForMessage:msg];
    }
    return total;
}

#pragma mark - Settings

- (void)setSystemPrompt:(NSString *)prompt {
    _systemPrompt = prompt ?: @"You are a helpful AI assistant.";
}

- (NSString *)systemPrompt {
    return _systemPrompt;
}

- (void)setTemperature:(float)temperature {
    _temperature = MAX(0.0, MIN(2.0, temperature));
}

- (float)temperature {
    return _temperature;
}

- (void)setMaxTokens:(NSUInteger)maxTokens {
    _maxTokens = MAX(1, MIN(32768, maxTokens));
}

- (NSUInteger)maxTokens {
    return _maxTokens;
}

@end