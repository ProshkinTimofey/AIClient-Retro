//
//  AIGeminiProvider.m
//  AIClient
//

#import "AIGeminiProvider.h"
#import "AIMessage.h"
#import "AIAttachment.h"
#import "AIHTTPClientFactory.h"
#import "AIStreamParser.h"

@interface AIGeminiProvider ()

@property (nonatomic, strong) id<AIHTTPClientProtocol> httpClient;
@property (nonatomic, strong) AIStreamParser *streamParser;

@end

@implementation AIGeminiProvider

- (instancetype)initWithAPIKey:(NSString *)apiKey {
    self = [super init];
    if (self) {
        _apiKey = apiKey;
        _apiBaseURL = @"https://generativelanguage.googleapis.com";
        _httpClient = [AIHTTPClientFactory createClientWithBaseURL:_apiBaseURL];
        _streamParser = [[AIStreamParser alloc] initWithProviderType:AIProviderTypeGemini];
    }
    return self;
}

#pragma mark - AIProviderProtocol

- (AIProviderType)providerType {
    return AIProviderTypeGemini;
}

- (NSString *)providerName {
    return @"Google Gemini";
}

- (NSArray<NSString *> *)availableChatModels {
    return @[@"gemini-1.5-pro", @"gemini-1.5-flash", @"gemini-1.0-pro", @"gemini-2.0-flash-exp"];
}

- (NSArray<NSString *> *)availableImageModels {
    return @[@"imagen-3.0-generate-002", @"imagen-2.0"];
}

- (NSUInteger)modelCapabilities {
    return AIModelCapabilityChat | AIModelCapabilityVision | AIModelCapabilityTools | AIModelCapabilityStreaming | AIModelCapabilityImageGeneration | AIModelCapabilityFileUpload;
}

- (BOOL)validateAPIKey:(NSString *)apiKey error:(NSError **)error {
    if (!apiKey || apiKey.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"AIGeminiProvider" code:1 userInfo:@{NSLocalizedDescriptionKey: @"API key is empty"}];
        return NO;
    }
    return YES;
}

- (void)setAPIKey:(NSString *)apiKey {
    _apiKey = apiKey;
    // Gemini uses query parameter for API key
}

- (BOOL)supportsStreaming {
    return YES;
}

- (AIStreamParser *)createStreamParser {
    return [[AIStreamParser alloc] initWithProviderType:AIProviderTypeGemini];
}

#pragma mark - Chat Completion

- (void)sendMessage:(AIMessage *)message
         attachments:(NSArray<AIAttachment *> *)attachments
        conversation:(NSArray<AIMessage *> *)history
           streamHandler:(void (^)(NSString *delta, BOOL isComplete, NSError *error))handler
           completion:(void (^)(AIMessage *response, NSError *error))completion {

    NSMutableArray *contents = [NSMutableArray array];

    // Add history
    for (AIMessage *msg in history) {
        [contents addObject:[self geminiContentFromAIMessage:msg]];
    }

    // Add current message
    [contents addObject:[self geminiContentFromAIMessage:message]];

    NSDictionary *body = @{
        @"contents": contents,
        @"generationConfig": @{
            @"temperature": @(0.7),
            @"maxOutputTokens": @(4096),
            @"topP": @(0.95),
            @"topK": @(40),
        },
        @"safetySettings": @[
            @{@"category": @"HARM_CATEGORY_HARASSMENT", @"threshold": @"BLOCK_MEDIUM_AND_ABOVE"},
            @{@"category": @"HARM_CATEGORY_HATE_SPEECH", @"threshold": @"BLOCK_MEDIUM_AND_ABOVE"},
            @{@"category": @"HARM_CATEGORY_SEXUALLY_EXPLICIT", @"threshold": @"BLOCK_MEDIUM_AND_ABOVE"},
            @{@"category": @"HARM_CATEGORY_DANGEROUS_CONTENT", @"threshold": @"BLOCK_MEDIUM_AND_ABOVE"},
        ]
    };

    NSString *model = message.model ?: @"gemini-1.5-pro";
    NSString *endpoint = [NSString stringWithFormat:@"/v1beta/models/%@:generateContent", model];
    if (handler) {
        endpoint = [NSString stringWithFormat:@"/v1beta/models/%@:streamGenerateContent", model];
    }

    NSString *urlString = [_apiBaseURL stringByAppendingString:endpoint];
    urlString = [urlString stringByAppendingString:[NSString stringWithFormat:@"?key=%@", _apiKey]];

    if (handler) {
        [_httpClient streamPOSTWithFullURL:urlString
                                      body:body
                                  onChunk:^(NSString *chunk) {
                                      [self.streamParser parseChunk:chunk
                                                       onDelta:^(NSString *delta) {
                                                           if (handler) handler(delta, NO, nil);
                                                       }
                                                       onComplete:^(NSDictionary *finalChunk) {
                                                           AIMessage *response = [self messageFromGeminiResponse:finalChunk];
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
        [_httpClient POSTWithFullURL:urlString
                               body:body
                          completion:^(NSData *data, NSError *error) {
                              if (error) {
                                  if (completion) completion(nil, error);
                                  return;
                              }
                              NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                              AIMessage *response = [self messageFromGeminiResponse:json];
                              if (completion) completion(response, nil);
                          }];
    }
}

- (NSDictionary *)geminiContentFromAIMessage:(AIMessage *)message {
    NSMutableDictionary *content = [NSMutableDictionary dictionary];
    content[@"role"] = [self geminiRoleForMessageRole:message.role];

    NSMutableArray *parts = [NSMutableArray array];

    // Text
    if (message.content.length > 0) {
        [parts addObject:@{@"text": message.content}];
    }

    // Attachments
    for (AIAttachment *att in message.attachments) {
        if (att.type == AIAttachmentTypeImage) {
            if (att.source == AIAttachmentSourceLocal || att.source == AIAttachmentSourceBase64) {
                NSData *imageData = [att loadImageData];
                if (imageData) {
                    NSString *base64 = [imageData base64EncodedStringWithOptions:0];
                    [parts addObject:@{
                        @"inlineData": @{
                            @"mimeType": att.mimeType ?: @"image/png",
                            @"data": base64
                        }
                    }];
                }
            } else if (att.source == AIAttachmentSourceRemote) {
                // Gemini supports file API for remote files
                if (att.providerFileID && [att.providerType isEqualToString:@"gemini"]) {
                    [parts addObject:@{
                        @"fileData": @{
                            @"mimeType": att.mimeType,
                            @"fileUri": att.providerFileID
                        }
                    }];
                }
            }
        } else if (att.type == AIAttachmentTypeDocument) {
            NSData *fileData = [att loadFileData];
            if (fileData) {
                NSString *base64 = [fileData base64EncodedStringWithOptions:0];
                [parts addObject:@{
                    @"inlineData": @{
                        @"mimeType": att.mimeType,
                        @"data": base64
                    }
                }];
            }
        }
    }

    content[@"parts"] = parts;
    return content;
}

- (NSString *)geminiRoleForMessageRole:(AIMessageRole)role {
    switch (role) {
        case AIMessageRoleSystem: return @"user"; // System prompts as user with special prefix
        case AIMessageRoleUser: return @"user";
        case AIMessageRoleAssistant: return @"model";
        case AIMessageRoleTool: return @"function";
        case AIMessageRoleFunction: return @"function";
    }
    return @"user";
}

- (AIMessage *)messageFromGeminiResponse:(NSDictionary *)json {
    NSArray *candidates = json[@"candidates"];
    if (!candidates || candidates.count == 0) return nil;

    NSDictionary *candidate = candidates[0];
    NSDictionary *content = candidate[@"content"];
    NSArray *parts = content[@"parts"];

    NSString *text = @"";
    for (NSDictionary *part in parts) {
        if (part[@"text"]) {
            text = [text stringByAppendingString:part[@"text"]];
        }
    }

    AIMessage *response = [[AIMessage alloc] initWithRole:AIMessageRoleAssistant content:text];
    response.model = json[@"modelVersion"] ?: @"gemini-1.5-pro";
    response.messageID = [NSString stringWithFormat:@"msg_%@", [[NSUUID UUID] UUIDString]];
    response.status = AIMessageStatusComplete;

    NSDictionary *usage = json[@"usageMetadata"];
    if (usage) {
        response.tokenCount = [usage[@"totalTokenCount"] unsignedIntegerValue];
    }

    return response;
}

#pragma mark - Image Generation (Imagen)

- (void)generateImageWithPrompt:(NSString *)prompt
                          model:(NSString *)model
                          size:(CGSize)size
                         quality:(NSString *)quality
                          n:(NSInteger)n
                    completion:(void (^)(NSArray<NSString *> *imageURLs, NSError *error))completion {

    NSString *imagenModel = model ?: @"imagen-3.0-generate-002";
    NSString *endpoint = [NSString stringWithFormat:@"/v1beta/models/%@:predict", imagenModel];

    NSDictionary *body = @{
        @"instances": @[
            @{@"prompt": prompt}
        ],
        @"parameters": @{
            @"sampleCount": @(n ?: 1),
            @"aspectRatio": size.width > size.height ? @"16:9" : (size.height > size.width ? @"9:16" : @"1:1"),
            @"personGeneration": @"allow_adult",
        }
    };

    NSString *urlString = [_apiBaseURL stringByAppendingString:endpoint];
    urlString = [urlString stringByAppendingString:[NSString stringWithFormat:@"?key=%@", _apiKey]];

    [_httpClient POSTWithFullURL:urlString
                           body:body
                      completion:^(NSData *data, NSError *error) {
                          if (error) {
                              if (completion) completion(nil, error);
                              return;
                          }
                          NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                          NSArray *predictions = json[@"predictions"];
                          NSMutableArray *urls = [NSMutableArray array];
                          for (NSDictionary *pred in predictions) {
                              if (pred[@"bytesBase64Encoded"]) {
                                  [urls addObject:[NSString stringWithFormat:@"data:image/png;base64,%@", pred[@"bytesBase64Encoded"]]];
                              }
                          }
                          if (completion) completion([urls copy], nil);
                      }];
}

#pragma mark - File Upload (Gemini File API)

- (void)uploadFile:(AIAttachment *)attachment
        completion:(void (^)(NSString *fileID, NSError *error))completion {

    if (![attachment validateForUpload:nil]) {
        if (completion) completion(nil, [NSError errorWithDomain:@"AIGeminiProvider" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid attachment for upload"}]);
        return;
    }

    NSData *fileData = [attachment loadFileData];
    if (!fileData) {
        if (completion) completion(nil, [NSError errorWithDomain:@"AIGeminiProvider" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Failed to load file data"}]);
        return;
    }

    // Step 1: Start resumable upload
    NSString *initEndpoint = @"/v1beta/files";
    NSDictionary *initBody = @{
        @"file": @{
            @"displayName": attachment.fileName,
            @"mimeType": attachment.mimeType,
        }
    };

    NSString *urlString = [_apiBaseURL stringByAppendingString:initEndpoint];
    urlString = [urlString stringByAppendingString:[NSString stringWithFormat:@"?key=%@", _apiKey]];

    [_httpClient POSTWithFullURL:urlString
                           body:initBody
                      completion:^(NSData *data, NSError *error) {
                          if (error) {
                              if (completion) completion(nil, error);
                              return;
                          }

                          NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                          NSString *uploadURL = json[@"resumableUploadUrl"];
                          NSString *fileName = json[@"file"][@"name"];

                          if (!uploadURL) {
                              if (completion) completion(nil, [NSError errorWithDomain:@"AIGeminiProvider" code:3 userInfo:@{NSLocalizedDescriptionKey: @"No upload URL returned"}]);
                              return;
                          }

                          // Step 2: Upload file data using factory client (PUT with full URL)
                          // We need to do a PUT request with the file data
                          [_httpClient uploadMultipartWithFullURL:uploadURL
                                                              data:fileData
                                                         mimeType:attachment.mimeType
                                                      completion:^(NSData *data, NSError *error) {
                                                          if (error) {
                                                              if (completion) completion(nil, error);
                                                              return;
                                                          }

                                                          // Step 3: Wait for file to be processed
                                                          [self waitForFileProcessing:fileName completion:^(BOOL success, NSError *err) {
                                                              if (success) {
                                                                  if (completion) completion(fileName, nil);
                                                              } else {
                                                                  if (completion) completion(nil, err);
                                                              }
                                                          }];
                                                      }];
                      }];
}

- (void)waitForFileProcessing:(NSString *)fileName completion:(void (^)(BOOL success, NSError *error))completion {
    NSString *endpoint = [NSString stringWithFormat:@"/v1beta/%@", fileName];
    NSString *urlString = [_apiBaseURL stringByAppendingString:endpoint];
    urlString = [urlString stringByAppendingString:[NSString stringWithFormat:@"?key=%@", _apiKey]];

    __block int attempts = 0;
    void (^checkStatus)() = ^(){
        attempts++;
        if (attempts > 60) { // Max 60 seconds
            completion(NO, [NSError errorWithDomain:@"AIGeminiProvider" code:4 userInfo:@{NSLocalizedDescriptionKey: @"File processing timeout"}]);
            return;
        }

        [_httpClient GETWithFullURL:urlString
                        completion:^(NSData *data, NSError *error) {
                            if (error) {
                                completion(NO, error);
                                return;
                            }
                            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                            NSString *state = json[@"state"];
                            if ([state isEqualToString:@"ACTIVE"]) {
                                completion(YES, nil);
                            } else if ([state isEqualToString:@"FAILED"]) {
                                completion(NO, [NSError errorWithDomain:@"AIGeminiProvider" code:5 userInfo:@{NSLocalizedDescriptionKey: @"File processing failed"}]);
                            } else {
                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), checkStatus);
                            }
                        }];
    };
    checkStatus();
}

@end