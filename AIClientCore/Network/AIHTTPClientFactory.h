//
//  AIHTTPClientFactory.h
//  AIClient
//
//  Factory for creating appropriate HTTP client based on iOS version.
//

#import <Foundation/Foundation.h>

@protocol AIHTTPClientProtocol <NSObject>

@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

- (void)setDefaultHeader:(NSString *)header value:(NSString *)value;
- (void)removeDefaultHeader:(NSString *)header;

- (void)GET:(NSString *)endpoint completion:(void (^)(NSData *data, NSError *error))completion;
- (void)POST:(NSString *)endpoint body:(NSDictionary *)body completion:(void (^)(NSData *data, NSError *error))completion;
- (void)PUT:(NSString *)endpoint body:(NSDictionary *)body completion:(void (^)(NSData *data, NSError *error))completion;
- (void)DELETE:(NSString *)endpoint completion:(void (^)(NSData *data, NSError *error))completion;

- (void)GETWithFullURL:(NSString *)url completion:(void (^)(NSData *data, NSError *error))completion;
- (void)POSTWithFullURL:(NSString *)url body:(NSDictionary *)body completion:(void (^)(NSData *data, NSError *error))completion;

- (void)streamPOST:(NSString *)endpoint body:(NSDictionary *)body onChunk:(void (^)(NSString *chunk))chunkHandler completion:(void (^)(NSData *data, NSError *error))completion;
- (void)streamPOSTWithFullURL:(NSString *)url body:(NSDictionary *)body onChunk:(void (^)(NSString *chunk))chunkHandler completion:(void (^)(NSData *data, NSError *error))completion;

- (void)uploadMultipart:(NSString *)endpoint files:(NSArray<NSDictionary *> *)files fields:(NSDictionary *)fields progress:(void (^)(float progress))progressHandler completion:(void (^)(NSData *data, NSError *error))completion;

// PUT upload for direct URLs (Gemini resumable upload)
- (void)uploadMultipartWithFullURL:(NSString *)url
                                data:(NSData *)data
                           mimeType:(NSString *)mimeType
                      completion:(void (^)(NSData *data, NSError *error))completion;

@end

@interface AIHTTPClientFactory : NSObject

+ (id<AIHTTPClientProtocol>)createClientWithBaseURL:(NSString *)baseURL;

// Returns YES if running on iOS 6 or earlier (requires legacy NSURLConnection client)
+ (BOOL)requiresLegacyClient;

@end