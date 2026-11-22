//
//  AIHTTPClient.h
//  AIClient
//

#import <Foundation/Foundation.h>

@interface AIHTTPClient : NSObject

@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

- (instancetype)initWithBaseURL:(NSString *)baseURL;

// Default headers for all requests
- (void)setDefaultHeader:(NSString *)header value:(NSString *)value;
- (void)removeDefaultHeader:(NSString *)header;

// Standard requests
- (void)GET:(NSString *)endpoint
   completion:(void (^)(NSData *data, NSError *error))completion;

- (void)POST:(NSString *)endpoint
        body:(NSDictionary *)body
   completion:(void (^)(NSData *data, NSError *error))completion;

- (void)PUT:(NSString *)endpoint
       body:(NSDictionary *)body
  completion:(void (^)(NSData *data, NSError *error))completion;

- (void)DELETE:(NSString *)endpoint
    completion:(void (^)(NSData *data, NSError *error))completion;

// Full URL requests (for providers with different base URLs per call)
- (void)GETWithFullURL:(NSString *)url
          completion:(void (^)(NSData *data, NSError *error))completion;

- (void)POSTWithFullURL:(NSString *)url
                 body:(NSDictionary *)body
            completion:(void (^)(NSData *data, NSError *error))completion;

// Streaming requests
- (void)streamPOST:(NSString *)endpoint
              body:(NSDictionary *)body
          onChunk:(void (^)(NSString *chunk))chunkHandler
         completion:(void (^)(NSData *data, NSError *error))completion;

- (void)streamPOSTWithFullURL:(NSString *)url
                       body:(NSDictionary *)body
                   onChunk:(void (^)(NSString *chunk))chunkHandler
                  completion:(void (^)(NSData *data, NSError *error))completion;

// Multipart upload
- (void)uploadMultipart:(NSString *)endpoint
                  files:(NSArray<NSDictionary *> *)files // @{@"name":, @"filename":, @"mimeType":, @"data":}
                 fields:(NSDictionary *)fields
            progress:(void (^)(float progress))progressHandler
           completion:(void (^)(NSData *data, NSError *error))completion;

@end