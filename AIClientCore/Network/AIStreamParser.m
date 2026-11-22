//
//  AIStreamParser.m
//  AIClient
//

#import "AIStreamParser.h"

@interface AIStreamParser ()

@property (nonatomic, assign) AIProviderType providerType;
@property (nonatomic, strong) NSMutableString *buffer;
@property (nonatomic, assign) BOOL receivedFirstChunk;

@end

@implementation AIStreamParser

- (instancetype)initWithProviderType:(AIProviderType)type {
    self = [super init];
    if (self) {
        _providerType = type;
        _buffer = [NSMutableString string];
        _receivedFirstChunk = NO;
    }
    return self;
}

- (void)reset {
    [_buffer setString:@""];
    _receivedFirstChunk = NO;
}

- (void)parseChunk:(NSString *)chunk
        onDelta:(void (^)(NSString *delta))deltaHandler
       onComplete:(void (^)(NSDictionary *finalChunk))completeHandler
         onError:(void (^)(NSError *error))errorHandler {

    if (!_receivedFirstChunk) {
        _receivedFirstChunk = YES;
    }

    [_buffer appendString:chunk];

    // Process based on provider
    switch (_providerType) {
        case AIProviderTypeOpenAI:
            [self parseOpenAIChunk:deltaHandler completeHandler:completeHandler errorHandler:errorHandler];
            break;
        case AIProviderTypeAnthropic:
            [self parseAnthropicChunk:deltaHandler completeHandler:completeHandler errorHandler:errorHandler];
            break;
        case AIProviderTypeGemini:
            [self parseGeminiChunk:deltaHandler completeHandler:completeHandler errorHandler:errorHandler];
            break;
        default:
            break;
    }
}

#pragma mark - OpenAI Parser (SSE format)

- (void)parseOpenAIChunk:(void (^)(NSString *))deltaHandler
          completeHandler:(void (^)(NSDictionary *))completeHandler
            errorHandler:(void (^)(NSError *))errorHandler {

    // OpenAI uses SSE: "data: {...}\n\n"
    NSArray *lines = [_buffer componentsSeparatedByString:@"\n"];
    NSMutableString *remaining = [NSMutableString string];

    for (NSString *line in lines) {
        if ([line hasPrefix:@"data: "]) {
            NSString *data = [line substringFromIndex:6];
            if ([data isEqualToString:@"[DONE]"]) {
                // Stream complete
                NSDictionary *final = @{@"choices": @[@{@"delta": @{}, @"finish_reason": @"stop"}]};
                completeHandler(final);
                [remaining setString:@""];
                continue;
            }

            NSError *error;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
            if (!error && json) {
                if (json[@"error"]) {
                    NSError *apiError = [NSError errorWithDomain:@"AIStreamParser" code:1 userInfo:@{NSLocalizedDescriptionKey: json[@"error"][@"message"] ?: @"API error"}];
                    errorHandler(apiError);
                    [remaining setString:@""];
                    continue;
                }

                NSArray *choices = json[@"choices"];
                if (choices && choices.count > 0) {
                    NSDictionary *choice = choices[0];
                    NSDictionary *delta = choice[@"delta"];
                    if (delta[@"content"]) {
                        deltaHandler(delta[@"content"]);
                    }
                    if (choice[@"finish_reason"]) {
                        completeHandler(json);
                    }
                }
            }
        } else if (line.length > 0) {
            // Keep incomplete lines
            [remaining appendString:line];
            [remaining appendString:@"\n"];
        }
    }

    [_buffer setString:remaining];
}

#pragma mark - Anthropic Parser (SSE format with event types)

- (void)parseAnthropicChunk:(void (^)(NSString *))deltaHandler
             completeHandler:(void (^)(NSDictionary *))completeHandler
               errorHandler:(void (^)(NSError *))errorHandler {

    // Anthropic uses SSE with event types
    NSArray *lines = [_buffer componentsSeparatedByString:@"\n"];
    NSMutableString *remaining = [NSMutableString string];
    NSString *currentEvent = nil;
    NSMutableString *currentData = [NSMutableString string];

    for (NSString *line in lines) {
        if ([line hasPrefix:@"event: "]) {
            currentEvent = [line substringFromIndex:7];
        } else if ([line hasPrefix:@"data: "]) {
            [currentData appendString:[line substringFromIndex:6]];
        } else if (line.length == 0) {
            // End of event
            if (currentData.length > 0) {
                NSError *error;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[currentData dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
                if (!error && json) {
                    if ([currentEvent isEqualToString:@"content_block_delta"]) {
                        NSDictionary *delta = json[@"delta"];
                        if (delta[@"text"]) {
                            deltaHandler(delta[@"text"]);
                        }
                    } else if ([currentEvent isEqualToString:@"message_stop"]) {
                        completeHandler(json);
                    } else if ([currentEvent isEqualToString:@"error"]) {
                        NSError *apiError = [NSError errorWithDomain:@"AIStreamParser" code:1 userInfo:@{NSLocalizedDescriptionKey: json[@"error"][@"message"] ?: @"API error"}];
                        errorHandler(apiError);
                    }
                }
                [currentData setString:@""];
            }
            currentEvent = nil;
        } else {
            [remaining appendString:line];
            [remaining appendString:@"\n"];
        }
    }

    [_buffer setString:remaining];
}

#pragma mark - Gemini Parser (JSON lines)

- (void)parseGeminiChunk:(void (^)(NSString *))deltaHandler
          completeHandler:(void (^)(NSDictionary *))completeHandler
            errorHandler:(void (^)(NSError *))errorHandler {

    // Gemini returns JSON objects separated by newlines
    NSArray *lines = [_buffer componentsSeparatedByString:@"\n"];
    NSMutableString *remaining = [NSMutableString string];

    for (NSString *line in lines) {
        if (line.length > 0 && ![line hasPrefix:@" "] && ![line hasPrefix:@"\t"]) {
            // Try to parse as JSON
            NSError *error;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
            if (!error && json) {
                if (json[@"error"]) {
                    NSError *apiError = [NSError errorWithDomain:@"AIStreamParser" code:1 userInfo:@{NSLocalizedDescriptionKey: json[@"error"][@"message"] ?: @"API error"}];
                    errorHandler(apiError);
                    [remaining setString:@""];
                    continue;
                }

                NSArray *candidates = json[@"candidates"];
                if (candidates && candidates.count > 0) {
                    NSDictionary *candidate = candidates[0];
                    NSDictionary *content = candidate[@"content"];
                    NSArray *parts = content[@"parts"];
                    for (NSDictionary *part in parts) {
                        if (part[@"text"]) {
                            deltaHandler(part[@"text"]);
                        }
                    }
                    if (candidate[@"finishReason"]) {
                        completeHandler(json);
                    }
                }
            } else {
                // Incomplete JSON, keep in buffer
                [remaining appendString:line];
                [remaining appendString:@"\n"];
            }
        } else if (line.length > 0) {
            [remaining appendString:line];
            [remaining appendString:@"\n"];
        }
    }

    [_buffer setString:remaining];
}

@end