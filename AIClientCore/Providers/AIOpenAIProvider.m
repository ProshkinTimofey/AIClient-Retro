//
//  AIOpenAIProvider.m
//  AIClient
//

#import "AIOpenAIProvider.h"
#import "AIMessage.h"
#import "AIAttachment.h"
#import "AIHTTPClientFactory.h"
#import "AIStreamParser.h"

@interface AIOpenAIProvider ()

@property (nonatomic, strong) id<AIHTTPClientProtocol> httpClient;
@property (nonatomic, strong) AIStreamParser *streamParser;

@end

@implementation AIOpenAIProvider

- (instancetype)initWithAPIKey:(NSString *)apiKey {
    self = [super init];
    if (self) {
        _apiKey = apiKey;
        _apiBaseURL = @"https://api.openai.com/v1";
        _apiVersion = @"2024-02-15-preview";
        _httpClient = [AIHTTPClientFactory createClientWithBaseURL:_apiBaseURL];
        _streamParser = [[AIStreamParser alloc] initWithProviderType:AIProviderTypeOpenAI];
    }
    return self;
}

#pragma mark - AIProviderProtocol

- (AIProviderType)providerType {
    return AIProviderTypeOpenAI;
}

- (NSString *)providerName {
    return @"OpenAI";
}

- (NSArray<NSString *> *)availableChatModels {
    return @[@"gpt-4o", @"gpt-4o-mini", @"gpt-4-turbo", @"gpt-4", @"gpt-3.5-turbo"];
}

- (NSArray<NSString *> *)availableImageModels {
    return @[@"dall-e-3", @"dall-e-2"];
}

- (NSUInteger)modelCapabilities {
    return AIModelCapabilityChat | AIModelCapabilityVision | AIModelCapabilityTools | AIModelCapabilityStreaming | AIModelCapabilityImageGeneration | AIModelCapabilityFileUpload;
}

- (BOOL)validateAPIKey:(NSString *)apiKey error:(NSError **)error {
    if (!apiKey || apiKey.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"AIOpenAIProvider" code:1 userInfo:@{NSLocalizedDescriptionKey: @"API key is empty"}];
        return NO;
    }
    if (![apiKey hasPrefix:@"sk-"]) {
        if (error) *error = [NSError errorWithDomain:@"AIOpenAIProvider" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid API key format (should start with sk-)"}];
        return NO;
    }
    return YES;
}

- (void)setAPIKey:(NSString *)apiKey {
    _apiKey = apiKey;
    [_httpClient setDefaultHeader:@"Authorization" value:[NSString stringWithFormat:@"Bearer %@", apiKey]];
    [_httpClient setDefaultHeader:@"OpenAI-Beta" value:_apiVersion];
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

    // System prompt (if first message)
    if (history.count == 0) {
        // Could add default system prompt here
    }

    // Add history
    for (AIMessage *msg in history) {
        [messages addObject:[self openAIMessageFromAIMessage:msg]];
    }

    // Add current message
    [messages addObject:[self openAIMessageFromAIMessage:message]];

    NSDictionary *body = @{
        @"model": message.model ?: @"gpt-4o",
        @"messages": messages,
        @"stream": @(handler != nil),
        @"temperature": @(0.7),
        @"max_tokens": @(4096),
    };

    NSString *endpoint = handler ? @"chat/completions" : @"chat/completions";

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
                                                AIMessage *response = [self messageFromOpenAIResponse:finalChunk];
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
                     AIMessage *response = [self messageFromOpenAIResponse:json];
                     if (completion) completion(response, nil);
                 }];
    }
}

- (NSDictionary *)openAIMessageFromAIMessage:(AIMessage *)message {
    NSMutableDictionary *msg = [NSMutableDictionary dictionary];
    msg[@"role"] = [self roleStringForMessageRole:message.role];
    msg[@"content"] = message.content;

    if (message.attachments.count > 0) {
        NSMutableArray *contentParts = [NSMutableArray array];

        // Text part
        if (message.content.length > 0) {
            [contentParts addObject:@{@"type": @"text", @"text": message.content}];
        }

        // Image parts
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
                // For documents, OpenAI uses file upload API
                if (att.providerFileID && [att.providerType isEqualToString:@"openai"]) {
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

- (AIMessage *)messageFromOpenAIResponse:(NSDictionary *)json {
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

#pragma mark - Image Generation (DALL-E)

- (void)generateImageWithPrompt:(NSString *)prompt
                          model:(NSString *)model
                          size:(CGSize)size
                         quality:(NSString *)quality
                          n:(NSInteger)n
                    completion:(void (^)(NSArray<NSString *> *imageURLs, NSError *error))completion {

    NSString *sizeString = [NSString stringWithFormat:@"%.0fx%.0f", size.width, size.height];
    NSArray<NSString *> *validSizes = @[@"1024x1024", @"1792x1024", @"1024x1792"];
    if (![validSizes containsObject:sizeString]) {
        sizeString = @"1024x1024";
    }

    NSDictionary *body = @{
        @"model": model ?: @"dall-e-3",
        @"prompt": prompt,
        @"n": @(n ?: 1),
        @"size": sizeString,
        @"quality": quality ?: @"standard",
        @"response_format": @"url"
    };

    [_httpClient POST:@"images/generations"
                 body:body
            completion:^(NSData *data, NSError *error) {
                if (error) {
                    if (completion) completion(nil, error);
                    return;
                }
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSArray *dataArray = json[@"data"];
                NSMutableArray *urls = [NSMutableArray array];
                for (NSDictionary *item in dataArray) {
                    if (item[@"url"]) [urls addObject:item[@"url"]];
                    if (item[@"b64_json"]) [urls addObject:[NSString stringWithFormat:@"data:image/png;base64,%@", item[@"b64_json"]]];
                }
                if (completion) completion([urls copy], nil);
            }];
}

#pragma mark - File Upload

- (void)uploadFile:(AIAttachment *)attachment
        completion:(void (^)(NSString *fileID, NSError *error))completion {

    if (![attachment validateForUpload:nil]) {
        if (completion) completion(nil, [NSError errorWithDomain:@"AIOpenAIProvider" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid attachment for upload"}]);
        return;
    }

    NSData *fileData = [attachment loadFileData];
    if (!fileData) {
        if (completion) completion(nil, [NSError errorWithDomain:@"AIOpenAIProvider" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Failed to load file data"}]);
        return;
    }

    // Use the factory client's uploadMultipart method
    NSDictionary *fields = @{@"purpose": @"assistants"};
    NSArray *files = @[@{
        @"name": @"file",
        @"filename": attachment.fileName,
        @"mimeType": attachment.mimeType ?: @"application/octet-stream",
        @"data": fileData
    }];

    [_httpClient uploadMultipart:@"files"
                           files:files
                          fields:fields
                     progress:nil
                completion:^(NSData *data, NSError *error) {
                    if (error) {
                        if (completion) completion(nil, error);
                        return;
                    }
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    NSString *fileID = json[@"id"];
                    if (completion) completion(fileID, nil);
                }];
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