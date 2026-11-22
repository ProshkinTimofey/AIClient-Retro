//
//  AIStreamParser.h
//  AIClient
//
//  Parses streaming responses from different AI providers.
//

#import <Foundation/Foundation.h>
#import "AIProviderProtocol.h"

@interface AIStreamParser : NSObject

- (instancetype)initWithProviderType:(AIProviderType)type;

- (void)parseChunk:(NSString *)chunk
        onDelta:(void (^)(NSString *delta))deltaHandler
       onComplete:(void (^)(NSDictionary *finalChunk))completeHandler
         onError:(void (^)(NSError *error))errorHandler;

- (void)reset;

@end