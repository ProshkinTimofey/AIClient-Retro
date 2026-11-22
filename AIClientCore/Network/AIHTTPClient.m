//
//  AIHTTPClient.m
//  AIClient
//

#import "AIHTTPClient.h"

@interface AIHTTPClient ()

@property (nonatomic, strong) NSMutableDictionary *defaultHeaders;
@property (nonatomic, strong) NSURLSessionConfiguration *sessionConfig;

@end

@implementation AIHTTPClient

- (instancetype)initWithBaseURL:(NSString *)baseURL {
    self = [super init];
    if (self) {
        _baseURL = baseURL;
        _timeoutInterval = 60.0;
        _defaultHeaders = [NSMutableDictionary dictionary];
        _defaultHeaders[@"Content-Type"] = @"application/json";
        _defaultHeaders[@"Accept"] = @"application/json";
        _defaultHeaders[@"User-Agent"] = @"AIClient/1.0 (iOS)";

        _sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        _sessionConfig.timeoutIntervalForRequest = _timeoutInterval;
        _sessionConfig.timeoutIntervalForResource = _timeoutInterval * 3;
        _session = [NSURLSession sessionWithConfiguration:_sessionConfig delegate:nil delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

- (void)setDefaultHeader:(NSString *)header value:(NSString *)value {
    if (value) {
        _defaultHeaders[header] = value;
    } else {
        [_defaultHeaders removeObjectForKey:header];
    }
}

- (void)removeDefaultHeader:(NSString *)header {
    [_defaultHeaders removeObjectForKey:header];
}

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method endpoint:(NSString *)endpoint body:(NSDictionary *)body {
    NSString *urlString = [_baseURL stringByAppendingString:[NSString stringWithFormat:@"/%@", endpoint]];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method;
    request.timeoutInterval = _timeoutInterval;

    for (NSString *header in _defaultHeaders) {
        [request setValue:_defaultHeaders[header] forHTTPHeaderField:header];
    }

    if (body) {
        NSError *error;
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
        if (error) {
            NSLog(@"AIHTTPClient: JSON serialization error: %@", error);
        }
    }

    return request;
}

- (NSMutableURLRequest *)requestWithFullURL:(NSString *)urlString method:(NSString *)method body:(NSDictionary *)body {
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method;
    request.timeoutInterval = _timeoutInterval;

    for (NSString *header in _defaultHeaders) {
        [request setValue:_defaultHeaders[header] forHTTPHeaderField:header];
    }

    if (body) {
        NSError *error;
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
        if (error) {
            NSLog(@"AIHTTPClient: JSON serialization error: %@", error);
        }
    }

    return request;
}

#pragma mark - Standard Requests

- (void)GET:(NSString *)endpoint completion:(void (^)(NSData *, NSError *))completion {
    NSMutableURLRequest *request = [self requestWithMethod:@"GET" endpoint:endpoint body:nil];
    [self performRequest:request completion:completion];
}

- (void)POST:(NSString *)endpoint body:(NSDictionary *)body completion:(void (^)(NSData *, NSError *))completion {
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" endpoint:endpoint body:body];
    [self performRequest:request completion:completion];
}

- (void)PUT:(NSString *)endpoint body:(NSDictionary *)body completion:(void (^)(NSData *, NSError *))completion {
    NSMutableURLRequest *request = [self requestWithMethod:@"PUT" endpoint:endpoint body:body];
    [self performRequest:request completion:completion];
}

- (void)DELETE:(NSString *)endpoint completion:(void (^)(NSData *, NSError *))completion {
    NSMutableURLRequest *request = [self requestWithMethod:@"DELETE" endpoint:endpoint body:nil];
    [self performRequest:request completion:completion];
}

- (void)GETWithFullURL:(NSString *)url completion:(void (^)(NSData *, NSError *))completion {
    NSMutableURLRequest *request = [self requestWithFullURL:url method:@"GET" body:nil];
    [self performRequest:request completion:completion];
}

- (void)POSTWithFullURL:(NSString *)url body:(NSDictionary *)body completion:(void (^)(NSData *, NSError *))completion {
    NSMutableURLRequest *request = [self requestWithFullURL:url method:@"POST" body:body];
    [self performRequest:request completion:completion];
}

- (void)performRequest:(NSMutableURLRequest *)request completion:(void (^)(NSData *, NSError *))completion {
    NSURLSessionDataTask *task = [_session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode >= 400) {
            NSString *errorMessage = @"Unknown error";
            if (data) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                errorMessage = json[@"error"][@"message"] ?: json[@"message"] ?: [NSString stringWithFormat:@"HTTP %ld", (long)httpResponse.statusCode];
            } else {
                errorMessage = [NSString stringWithFormat:@"HTTP %ld", (long)httpResponse.statusCode];
            }
            NSError *apiError = [NSError errorWithDomain:@"AIHTTPClient" code:httpResponse.statusCode userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(data, apiError);
            });
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(data, nil);
        });
    }];
    [task resume];
}

#pragma mark - Streaming Requests

- (void)streamPOST:(NSString *)endpoint body:(NSDictionary *)body onChunk:(void (^)(NSString *))chunkHandler completion:(void (^)(NSData *, NSError *))completion {
    NSString *urlString = [_baseURL stringByAppendingString:[NSString stringWithFormat:@"/%@", endpoint]];
    [self streamPOSTWithFullURL:urlString body:body onChunk:chunkHandler completion:completion];
}

- (void)streamPOSTWithFullURL:(NSString *)url body:(NSDictionary *)body onChunk:(void (^)(NSString *))chunkHandler completion:(void (^)(NSData *, NSError *))completion {
    NSMutableURLRequest *request = [self requestWithFullURL:url method:@"POST" body:body];

    // Use a custom NSURLSession with delegate for streaming
    AIStreamingSessionDelegate *delegate = [[AIStreamingSessionDelegate alloc] initWithChunkHandler:chunkHandler completion:completion];
    NSURLSession *streamSession = [NSURLSession sessionWithConfiguration:_sessionConfig delegate:delegate delegateQueue:[NSOperationQueue mainQueue]];
    delegate.session = streamSession;

    NSURLSessionDataTask *task = [streamSession dataTaskWithRequest:request];
    [task resume];
}

#pragma mark - Multipart Upload

- (void)uploadMultipart:(NSString *)endpoint files:(NSArray<NSDictionary *> *)files fields:(NSDictionary *)fields progress:(void (^)(float))progressHandler completion:(void (^)(NSData *, NSError *))completion {
    NSString *urlString = [_baseURL stringByAppendingString:[NSString stringWithFormat:@"/%@", endpoint]];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 300; // 5 min for uploads

    NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];

    for (NSString *header in _defaultHeaders) {
        if (![header isEqualToString:@"Content-Type"]) {
            [request setValue:_defaultHeaders[header] forHTTPHeaderField:header];
        }
    }

    NSMutableData *body = [NSMutableData data];

    // Fields
    for (NSString *key in fields) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"%@\r\n", fields[key]] dataUsingEncoding:NSUTF8StringEncoding]];
    }

    // Files
    for (NSDictionary *file in files) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", file[@"name"], file[@"filename"]] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", file[@"mimeType"]] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:file[@"data"]];
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }

    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    request.HTTPBody = body;

    // Upload with progress
    AIUploadSessionDelegate *delegate = [[AIUploadSessionDelegate alloc] initWithProgressHandler:progressHandler completion:completion];
    NSURLSession *uploadSession = [NSURLSession sessionWithConfiguration:_sessionConfig delegate:delegate delegateQueue:[NSOperationQueue mainQueue]];
    delegate.session = uploadSession;

    NSURLSessionUploadTask *task = [uploadSession uploadTaskWithRequest:request fromData:body];
    [task resume];
}

- (void)uploadMultipartWithFullURL:(NSString *)url
                                data:(NSData *)data
                           mimeType:(NSString *)mimeType
                      completion:(void (^)(NSData *, NSError *))completion {
    NSURL *nsurl = [NSURL URLWithString:url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:nsurl
                                                          cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                      timeoutInterval:300.0];
    request.HTTPMethod = @"PUT";
    request.HTTPBody = data;
    [request setValue:mimeType forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%llu", (unsigned long long)data.length] forHTTPHeaderField:@"Content-Length"];

    // Copy auth headers
    for (NSString *header in _defaultHeaders) {
        [request setValue:_defaultHeaders[header] forHTTPHeaderField:header];
    }

    NSURLSessionDataTask *task = [_session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(data, nil);
        });
    }];
    [task resume];
}

@end

// Streaming delegate
@interface AIStreamingSessionDelegate : NSObject <NSURLSessionDataDelegate>
@property (nonatomic, copy) void (^)(NSString *)chunkHandler;
@property (nonatomic, copy) void (^)(NSData *, NSError *)completion;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableData *buffer;
@end

@implementation AIStreamingSessionDelegate

- (instancetype)initWithChunkHandler:(void (^)(NSString *))chunkHandler completion:(void (^)(NSData *, NSError *))completion {
    self = [super init];
    if (self) {
        _chunkHandler = chunkHandler;
        _completion = completion;
        _buffer = [NSMutableData data];
    }
    return self;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [_buffer appendData:data];

    // Process complete lines
    NSString *bufferString = [[NSString alloc] initWithData:_buffer encoding:NSUTF8StringEncoding];
    NSArray *lines = [bufferString componentsSeparatedByString:@"\n"];

    // Keep last incomplete line in buffer
    if (lines.count > 0) {
        NSString *lastLine = lines.lastObject;
        if (![lastLine hasSuffix:@"\n"] && ![bufferString hasSuffix:@"\n"]) {
            _buffer = [lastLine dataUsingEncoding:NSUTF8StringEncoding];
            lines = [lines subarrayWithRange:NSMakeRange(0, lines.count - 1)];
        } else {
            _buffer = [NSMutableData data];
        }

        for (NSString *line in lines) {
            if (line.length > 0) {
                _chunkHandler(line);
            }
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        _completion(nil, error);
    } else {
        _completion(_buffer, nil);
    }
    [self.session invalidateAndCancel];
}

@end

// Upload delegate with progress
@interface AIUploadSessionDelegate : NSObject <NSURLSessionTaskDelegate>
@property (nonatomic, copy) void (^)(float)progressHandler;
@property (nonatomic, copy) void (^)(NSData *, NSError *)completion;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableData *responseData;
@end

@implementation AIUploadSessionDelegate

- (instancetype)initWithProgressHandler:(void (^)(float))progressHandler completion:(void (^)(NSData *, NSError *))completion {
    self = [super init];
    if (self) {
        _progressHandler = progressHandler;
        _completion = completion;
        _responseData = [NSMutableData data];
    }
    return self;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    if (totalBytesExpectedToSend > 0) {
        float progress = (float)totalBytesSent / (float)totalBytesExpectedToSend;
        dispatch_async(dispatch_get_main_queue(), ^{
            _progressHandler(progress);
        });
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [_responseData appendData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        _completion(nil, error);
    } else {
        _completion(_responseData, nil);
    }
    [self.session invalidateAndCancel];
}

@end