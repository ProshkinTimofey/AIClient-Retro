//
//  AIAnthropicProvider.m
//  AIClient
//

#import "AIAnthropicProvider.h"
#import "AIMessage.h"
#import "AIAttachment.h"
#import "AIHTTPClientFactory.h"
#import "AIStreamParser.h"

@interface AIAnthropicProvider ()

@property (nonatomic, strong) id<AIHTTPClientProtocol> httpClient;
@property (nonatomic, strong) AIStreamParser *streamParser;

@end

@implementation AIAnthropicProvider

- (instancetype)initWithAPIKey:(NSString *)apiKey {
    self = [super init];
    if (self) {
        _apiKey = apiKey;
        _apiBaseURL = @"https://api.anthropic.com";
        _apiVersion = @"2023-06-01";
        _httpClient = [AIHTTPClientFactory createClientWithBaseURL:_apiBaseURL];
        _streamParser = [[AIStreamParser alloc] initWithProviderType:AIProviderTypeAnthropic];
    }
    return self;
}

#pragma mark - AIProviderProtocol

- (AIProviderType)providerType {
    return AIProviderTypeAnthropic;
}

- (NSString *)providerName {
    return @"Anthropic";
}

- (NSArray<NSString *> *)availableChatModels {
    return @[@"claude-opus-4-20250514", @"claude-sonnet-4-20250514", @"claude-3-5-sonnet-20241022", @"claude-3-5-haiku-20241022", @"claude-3-opus-20240229"];
}

- (NSArray<NSString *> *)availableImageModels {
    return @[]; // Anthropic doesn't do image generation directly
}

- (NSUInteger)modelCapabilities {
    return AIModelCapabilityChat | AIModelCapabilityVision | AIModelCapabilityTools | AIModelCapabilityStreaming | AIModelCapabilityFileUpload;
}

- (BOOL)validateAPIKey:(NSString *)apiKey error:(NSError **)error {
    if (!apiKey || apiKey.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"AIAnthropicProvider" code:1 userInfo:@{NSLocalizedDescriptionKey: @"API key is empty"}];
        return NO;
    }
    if (![apiKey hasPrefix:@"sk-ant-"]) {
        if (error) *error = [NSError errorWithDomain:@"AIAnthropicProvider" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid API key format (should start with sk-ant-)"}];
        return NO;
    }
    return YES;
}

- (void)setAPIKey:(NSString *)apiKey {
    _apiKey = apiKey;
    [_httpClient setDefaultHeader:@"x-api-key" value:apiKey];
    [_httpClient setDefaultHeader:@"anthropic-version" value:_apiVersion];
}

- (BOOL)supportsStreaming {
    return YES;
}

- (AIStreamParser *)createStreamParser {
    return [[AIStreamParser alloc] initWithProviderType:AIProviderTypeAnthropic];
}

#pragma mark - Chat Completion

- (void)sendMessage:(AIMessage *)message
         attachments:(NSArray<AIAttachment *> *)attachments
        conversation:(NSArray<AIMessage *> *)history
           streamHandler:(void (^)(NSString *delta, BOOL isComplete, NSError *error))handler
           completion:(void (^)(AIMessage *response, NSError *error))completion {

    NSMutableArray *messages = [NSMutableArray array];

    // System prompt extraction
    NSString *systemPrompt = nil;
    NSMutableArray *userMessages = [NSMutableArray array];

    for (AIMessage *msg in history) {
        if (msg.role == AIMessageRoleSystem && !systemPrompt) {
            systemPrompt = msg.content;
        } else {
            [userMessages addObject:[self anthropicMessageFromAIMessage:msg]];
        }
    }

    // Add current message
    [userMessages addObject:[self anthropicMessageFromAIMessage:message]];

    NSDictionary *body = @{
        @"model": message.model ?: @"claude-3-5-sonnet-20241022",
        @"messages": userMessages,
        @"stream": @(handler != nil),
        @"max_tokens": @(4096),
        @"temperature": @(0.7),
    };

    if (systemPrompt && systemPrompt.length > 0) {
        body = [body mutableCopy];
        ((NSMutableDictionary *)body)[@"system"] = systemPrompt;
    }

    NSString *endpoint = @"v1/messages";

    if (handler) {
        [_httpClient streamPOST:endpoint
                           body:body
                       onChunk:^(NSString *chunk) {
                           [self.streamParser parseChunk:chunk
                                            onDelta:^(NSString *delta) {
                                                if (handler) handler(delta, NO, nil);
                                            }
                                            onComplete:^(NSDictionary *finalChunk) {
                                                AIMessage *response = [self messageFromAnthropicResponse:finalChunk];
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
        [_httpClient POST:endpoint
                      body:body
                 completion:^(NSData *data, NSError *error) {
                     if (error) {
                         if (completion) completion(nil, error);
                         return;
                     }
                     NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                     AIMessage *response = [self messageFromAnthropicResponse:json];
                     if (completion) completion(response, nil);
                 }];
    }
}

- (NSDictionary *)anthropicMessageFromAIMessage:(AIMessage *)message {
    NSMutableDictionary *msg = [NSMutableDictionary dictionary];
    msg[@"role"] = [self roleStringForMessageRole:message.role];
    msg[@"content"] = message.content;

    if (message.attachments.count > 0) {
        NSMutableArray *contentParts = [NSMutableArray array];

        if (message.content.length > 0) {
            [contentParts addObject:@{@"type": @"text", @"text": message.content}];
        }

        for (AIAttachment *att in message.attachments) {
            if (att.type == AIAttachmentTypeImage) {
                if (att.source == AIAttachmentSourceLocal || att.source == AIAttachmentSourceBase64) {
                    NSData *imageData = [att loadImageData];
                    if (imageData) {
                        NSString *base64 = [imageData base64EncodedStringWithOptions:0];
                        NSString *mediaType = [self mediaTypeForMIMEType:att.mimeType];
                        [contentParts addObject:@{
                            @"type": @"image",
                            @"source": @{
                                @"type": @"base64",
                                @"media_type": mediaType,
                                @"data": base64
                            }
                        }];
                    }
                } else if (att.source == AIAttachmentSourceRemote) {
                    // Anthropic doesn't support remote URLs directly
                    // Would need to download and convert to base64
                }
            } else if (att.type == AIAttachmentTypeDocument) {
                // Documents via base64
                NSData *fileData = [att loadFileData];
                if (fileData) {
                    NSString *base64 = [fileData base64EncodedStringWithOptions:0];
                    [contentParts addObject:@{
                        @"type": @"document",
                        @"source": @{
                            @"type": @"base64",
                            @"media_type": att.mimeType,
                            @"data": base64
                        }
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
        case AIMessageRoleSystem: return @"system"; // Handled separately
        case AIMessageRoleUser: return @"user";
        case AIMessageRoleAssistant: return @"assistant";
        case AIMessageRoleTool: return @"user"; // Tool results go as user
        case AIMessageRoleFunction: return @"user";
    }
    return @"user";
}

- (NSString *)mediaTypeForMIMEType:(NSString *)mimeType {
    if ([mimeType hasPrefix:@"image/"]) return mimeType;
    if ([mimeType isEqualToString:@"application/pdf"]) return @"application/pdf";
    if ([mimeType hasPrefix:@"text/"]) return @"text/plain";
    return @"application/octet-stream";
}

- (AIMessage *)messageFromAnthropicResponse:(NSDictionary *)json {
    NSArray *content = json[@"content"];
    NSString *text = @"";
    for (NSDictionary *block in content) {
        if ([block[@"type"] isEqualToString:@"text"]) {
            text = [text stringByAppendingString:block[@"text"]];
        }
    }

    AIMessage *response = [[AIMessage alloc] initWithRole:AIMessageRoleAssistant content:text];
    response.model = json[@"model"];
    response.messageID = [NSString stringWithFormat:@"msg_%@", json[@"id"] ?: @""];
    response.status = AIMessageStatusComplete;

    NSDictionary *usage = json[@"usage"];
    if (usage) {
        response.tokenCount = [usage[@"input_tokens"] unsignedIntegerValue] + [usage[@"output_tokens"] unsignedIntegerValue];
    }

    return response;
}

#pragma mark - Image Generation (Not supported by Anthropic directly)

- (void)generateImageWithPrompt:(NSString *)prompt
                          model:(NSString *)model
                          size:(CGSize)size
                         quality:(NSString *)quality
                          n:(NSInteger)n
                    completion:(void (^)(NSArray<NSString *> *imageURLs, NSError *error))completion {
    if (completion) completion(nil, [NSError errorWithDomain:@"AIAnthropicProvider" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Anthropic does not support image generation"}]);
}

#pragma mark - File Upload (Anthropic uses base64 inline, no separate file API)

- (void)uploadFile:(AIAttachment *)attachment
        completion:(void (^)(NSString *fileID, NSError *error))completion {
    // Anthropic doesn't have a separate file upload API - files are sent inline as base64
    if (completion) completion(nil, [NSError errorWithDomain:@"AIAnthropicProvider" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Anthropic uses inline base64 for files, no file upload API"}]);
}

@end