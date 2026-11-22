//
//  AINVIDIAProvider.m
//  AIClient
//
//  NVIDIA NIM Provider - API compatible with OpenAI format
//  Default base URL: https://integrate.api.nvidia.com/v1
//

#import "AINVIDIAProvider.h"
#import "AIMessage.h"
#import "AIAttachment.h"
#import "AIHTTPClientFactory.h"
#import "AIStreamParser.h"

@interface AINVIDIAProvider ()

@property (nonatomic, strong) id<AIHTTPClientProtocol> httpClient;
@property (nonatomic, strong) AIStreamParser *streamParser;
@property (nonatomic, copy) NSString *apiVersion;

@end

@implementation AINVIDIAProvider

- (instancetype)initWithAPIKey:(NSString *)apiKey baseURL:(NSString *)baseURL {
    self = [super init];
    if (self) {
        _apiKey = apiKey;
        _apiBaseURL = baseURL ?: @"https://integrate.api.nvidia.com/v1";
        _apiVersion = @"2024-02-15-preview";
        _httpClient = [AIHTTPClientFactory createClientWithBaseURL:_apiBaseURL];
        // NVIDIA uses OpenAI-compatible SSE format
        _streamParser = [[AIStreamParser alloc] initWithProviderType:AIProviderTypeOpenAI];
    }
    return self;
}

- (instancetype)initWithAPIKey:(NSString *)apiKey {
    return [self initWithAPIKey:apiKey baseURL:nil];
}

#pragma mark - AIProviderProtocol

- (AIProviderType)providerType {
    return AIProviderTypeNVIDIA;
}

- (NSString *)providerName {
    return @"NVIDIA NIM";
}

- (NSArray<NSString *> *)availableChatModels {
    return @[
        // NVIDIA NIM models (examples - actual models depend on deployment)
        @"meta/llama-3.1-405b-instruct",
        @"meta/llama-3.1-70b-instruct",
        @"meta/llama-3.1-8b-instruct",
        @"nvidia/nemotron-3-ultra",
        @"nvidia/nemotron-3-ultra-4k",
        @"mistralai/mixtral-8x22b-instruct",
        @"google/gemma-2-27b-it",
        @"google/gemma-2-9b-it",
        @"microsoft/phi-3-medium-128k-instruct",
        @"microsoft/phi-3-mini-128k-instruct"
    ];
}

- (NSArray<NSString *> *)availableImageModels {
    return @[]; // NIM doesn't typically do image generation
}

- (NSUInteger)modelCapabilities {
    return AIModelCapabilityChat | AIModelCapabilityVision | AIModelCapabilityTools | AIModelCapabilityStreaming | AIModelCapabilityFileUpload;
}

- (BOOL)validateAPIKey:(NSString *)apiKey error:(NSError **)error {
    if (!apiKey || apiKey.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"AINVIDIAProvider" code:1 userInfo:@{NSLocalizedDescriptionKey: @"API key is empty"}];
        return NO;
    }
    // NVIDIA NIM keys typically start with "nvapi-"
    if (![apiKey hasPrefix:@"nvapi-"]) {
        if (error) *error = [NSError errorWithDomain:@"AINVIDIAProvider" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid API key format (should start with nvapi-)"}];
        return NO;
    }
    return YES;
}

- (void)setAPIKey:(NSString *)apiKey {
    _apiKey = apiKey;
    [_httpClient setDefaultHeader:@"Authorization" value:[NSString stringWithFormat:@"Bearer %@", apiKey]];
    // NVIDIA NIM doesn't require special beta header
}

- (BOOL)supportsStreaming {
    return YES;
}

- (AIStreamParser *)createStreamParser {
    return [[AIStreamParser alloc] initWithProviderType:AIProviderTypeOpenAI];
}

#pragma mark - Chat Completion

- (void)sendMessage:(AIMessage *)message
         attachments:(NSArray<AIAttachment *> *)attachments
        conversation:(NSArray<AIMessage *> *)history
           streamHandler:(void (^)(NSString *delta, BOOL isComplete, NSError *error))handler
           completion:(void (^)(AIMessage *response, NSError *error))completion {

    NSMutableArray *messages = [NSMutableArray array];

    // Add history
    for (AIMessage *msg in history) {
        [messages addObject:[self nvidiaMessageFromAIMessage:msg]];
    }

    // Add current message
    [messages addObject:[self nvidiaMessageFromAIMessage:message]];

    NSDictionary *body = @{
        @"model": message.model ?: @"meta/llama-3.1-70b-instruct",
        @"messages": messages,
        @"stream": @(handler != nil),
        @"temperature": @(0.7),
        @"max_tokens": @(4096),
    };

    NSString *endpoint = @"chat/completions";

    if (handler) {
        // Streaming request
        [_httpClient streamPOST:endpoint
                           body:body
                       onChunk:^(NSString *chunk) {
                           [self.streamParser parseChunk:chunk
                                            onDelta:^(NSString *delta) {
                                                if (handler) handler(delta, NO, nil);
                                            }
                                            onComplete:^(NSDictionary *finalChunk) {
                                                AIMessage *response = [self messageFromNVIDIAResponse:finalChunk];
                                                if (handler) handler(@"", YES, nil);
                                                if (completion) completion(response, nil);
                                            }
                                            onError:^(NSError *err) {
                                                if (handler) handler(@"", YES, err);
                                                if (completion) completion(nil, err);
                                            }];
                       }
                       completion:^(NSData *data, NSError *error) {
                           // Handled by stream parser
                       }];
    } else {
        // Non-streaming request
        [_httpClient POST:endpoint
                      body:body
                 completion:^(NSData *data, NSError *error) {
                     if (error) {
                         if (completion) completion(nil, error);
                         return;
                     }
                     NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                     AIMessage *response = [self messageFromNVIDIAResponse:json];
                     if (completion) completion(response, nil);
                 }];
    }
}

- (NSDictionary *)nvidiaMessageFromAIMessage:(AIMessage *)message {
    NSMutableDictionary *msg = [NSMutableDictionary dictionary];
    msg[@"role"] = [self roleStringForMessageRole:message.role];
    msg[@"content"] = message.content;

    if (message.attachments.count > 0) {
        NSMutableArray *contentParts = [NSMutableArray array];

        // Text part
        if (message.content.length > 0) {
            [contentParts addObject:@{@"type": @"text", @"text": message.content}];
        }

        // Image parts (OpenAI-compatible format)
        for (AIAttachment *att in message.attachments) {
            if (att.type == AIAttachmentTypeImage) {
                if (att.source == AIAttachmentSourceLocal || att.source == AIAttachmentSourceBase64) {
                    NSData *imageData = [att loadImageData];
                    if (imageData) {
                        NSString *base64 = [imageData base64EncodedStringWithOptions:0];
                        NSString *mimeType = att.mimeType ?: @"image/png";
                        [contentParts addObject:@{
                            @"type": @"image_url",
                            @"image_url": @{@"url": [NSString stringWithFormat:@"data:%@;base64,%@", mimeType, base64], @"detail": @"high"}
                        }];
                    }
                } else if (att.source == AIAttachmentSourceRemote) {
                    [contentParts addObject:@{
                        @"type": @"image_url",
                        @"image_url": @{@"url": att.remoteURL, @"detail": @"high"}
                    }];
                }
            } else if (att.type == AIAttachmentTypeDocument) {
                // Documents via file ID if uploaded
                if (att.providerFileID && [att.providerType isEqualToString:@"nvidia"]) {
                    [contentParts addObject:@{
                        @"type": @"file",
                        @"file": @{@"file_id": att.providerFileID}
                    }];
                }
            }
        }

        msg[@"content"] = contentParts;
    }

    return msg;
}

- (NSString *)roleStringForMessageRole:(AIMessageRole)role {
    switch (role) {
        case AIMessageRoleSystem: return @"system";
        case AIMessageRoleUser: return @"user";
        case AIMessageRoleAssistant: return @"assistant";
        case AIMessageRoleTool: return @"tool";
        case AIMessageRoleFunction: return @"function";
    }
    return @"user";
}

- (AIMessage *)messageFromNVIDIAResponse:(NSDictionary *)json {
    NSArray *choices = json[@"choices"];
    if (!choices || choices.count == 0) return nil;

    NSDictionary *choice = choices[0];
    NSDictionary *message = choice[@"message"];

    AIMessage *response = [[AIMessage alloc] initWithRole:AIMessageRoleAssistant content:message[@"content"]];
    response.model = json[@"model"];
    response.messageID = [NSString stringWithFormat:@"msg_%@", json[@"id"] ?: @""];
    response.status = AIMessageStatusComplete;

    NSDictionary *usage = json[@"usage"];
    if (usage) {
        response.tokenCount = [usage[@"total_tokens"] unsignedIntegerValue];
    }

    if (message[@"tool_calls"]) {
        response.metadata = @{@"tool_calls": message[@"tool_calls"]};
    }

    return response;
}

#pragma mark - Image Generation (Not supported by NIM)

- (void)generateImageWithPrompt:(NSString *)prompt
                          model:(NSString *)model
                          size:(CGSize)size
                         quality:(NSString *)quality
                          n:(NSInteger)n
                    completion:(void (^)(NSArray<NSString *> *imageURLs, NSError *error))completion {
    if (completion) completion(nil, [NSError errorWithDomain:@"AINVIDIAProvider" code:1 userInfo:@{NSLocalizedDescriptionKey: @"NVIDIA NIM does not support image generation"}]);
}

#pragma mark - File Upload (Not directly supported by NIM API)

- (void)uploadFile:(AIAttachment *)attachment
        completion:(void (^)(NSString *fileID, NSError *error))completion {
    // NIM typically doesn't have a separate file upload API
    // Files are sent inline as base64 in chat requests
    if (completion) completion(nil, [NSError errorWithDomain:@"AINVIDIAProvider" code:1 userInfo:@{NSLocalizedDescriptionKey: @"NVIDIA NIM uses inline base64 for files, no separate file upload API"}]);
}

#pragma mark - Models Fetching

- (void)fetchAvailableModelsWithCompletion:(void (^)(NSArray<NSString *> *models, NSError *error))completion {
    [_httpClient GET:@"models"
              completion:^(NSData *data, NSError *error) {
                  if (error) {
                      if (completion) completion(nil, error);
                      return;
                  }
                  NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                  NSArray *dataArray = json[@"data"];
                  NSMutableArray *models = [NSMutableArray array];
                  for (NSDictionary *model in dataArray) {
                      [models addObject:model[@"id"]];
                  }
                  if (completion) completion([models copy], nil);
              }];
}

@end