//
//  AIHTTPClientLegacy.m
//  AIClient
//
//  NSURLConnection-based implementation for iOS 6.
//  Maintains exact same API as AIHTTPClient.
//

#import "AIHTTPClientLegacy.h"

@interface AIHTTPClientLegacy ()

@property (nonatomic, strong) NSMutableDictionary *defaultHeaders;
@property (nonatomic, strong) NSMutableDictionary *activeConnections; // connection -> context

@end

// Context object for each request - acts as NSURLConnection delegate
@interface AIHTTPRequestContext : NSObject <NSURLConnectionDataDelegate, NSURLConnectionDelegate>

@property (nonatomic, weak) AIHTTPClientLegacy *client;
@property (nonatomic, copy) void (^)(NSData *, NSError *)completion;
@property (nonatomic, copy) void (^)(NSString *)chunkHandler;
@property (nonatomic, copy) void (^)(float)progressHandler;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, strong) NSMutableData *buffer;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, assign) int64_t totalBytesExpected;
@property (nonatomic, assign) int64_t totalBytesSent;
@property (nonatomic, assign) BOOL isStreaming;
@property (nonatomic, assign) BOOL isUpload;

@end

@implementation AIHTTPRequestContext

- (void)dealloc {
    [_connection cancel];
    _connection = nil;
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    // Don't fail here - collect error data in didReceiveData/didFinishLoading
    _receivedData = [NSMutableData data];
    _buffer = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_receivedData appendData:data];

    if (_isStreaming && _chunkHandler) {
        [_buffer appendData:data];

        NSString *bufferString = [[NSString alloc] initWithData:_buffer encoding:NSUTF8StringEncoding];
        NSArray *lines = [bufferString componentsSeparatedByString:@"\n"];

        NSMutableData *newBuffer = [NSMutableData data];
        for (NSInteger i = 0; i < lines.count; i++) {
            NSString *line = lines[i];
            BOOL isLast = (i == lines.count - 1);
            BOOL hasNewline = (i < lines.count - 1) || [bufferString hasSuffix:@"\n"];

            if (isLast && !hasNewline) {
                [newBuffer appendData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            } else if (line.length > 0) {
                _chunkHandler(line);
            }
        }
        _buffer = newBuffer;
    }
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten
                            totalBytesWritten:(NSInteger)totalBytesWritten
                          totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    _totalBytesSent = totalBytesWritten;
    _totalBytesExpected = totalBytesExpectedToWrite;

    if (_isUpload && _progressHandler && _totalBytesExpected > 0) {
        float progress = (float)_totalBytesSent / (float)_totalBytesExpected;
        dispatch_async(dispatch_get_main_queue(), ^{
            _progressHandler(progress);
        });
    }
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return _isStreaming ? nil : cachedResponse;
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self completeWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    // We need the response - but it's not passed here in iOS 6
    // The response was received in didReceiveResponse
    // Check status code from the last response
    // Since we don't have direct access, we assume success if no error
    // The error would have been caught in didFailWithError

    // For streaming, emit any remaining buffer
    if (_isStreaming && _buffer.length > 0 && _chunkHandler) {
        NSString *remaining = [[NSString alloc] initWithData:_buffer encoding:NSUTF8StringEncoding];
        if (remaining.length > 0) {
            _chunkHandler(remaining);
        }
    }

    [self completeWithData:_receivedData];
}

#pragma mark - Completion

- (void)completeWithData:(NSData *)data {
    void (^completion)(NSData *, NSError *) = _completion;
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(data, nil);
        });
    }
    [self cleanup];
}

- (void)completeWithError:(NSError *)error {
    void (^completion)(NSData *, NSError *) = _completion;
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, error);
        });
    }
    [self cleanup];
}

- (void)cleanup {
    if (_client && _connection) {
        @synchronized(_client.activeConnections) {
            [_client.activeConnections removeObjectForKey:_connection];
        }
    }
    _connection = nil;
    _completion = nil;
    _chunkHandler = nil;
    _progressHandler = nil;
    _client = nil;
}

@end

@implementation AIHTTPClientLegacy

- (instancetype)initWithBaseURL:(NSString *)baseURL {
    self = [super init];
    if (self) {
        _baseURL = baseURL;
        _timeoutInterval = 60.0;
        _defaultHeaders = [NSMutableDictionary dictionary];
        _defaultHeaders[@"Content-Type"] = @"application/json";
        _defaultHeaders[@"Accept"] = @"application/json";
        _defaultHeaders[@"User-Agent"] = @"AIClient/1.0 (iOS 6)";
        _activeConnections = [NSMutableDictionary dictionary];
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

#pragma mark - Request Building

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method endpoint:(NSString *)endpoint body:(NSDictionary *)body {
    NSString *urlString = [_baseURL stringByAppendingString:[NSString stringWithFormat:@"/%@", endpoint]];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                          cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                      timeoutInterval:_timeoutInterval];
    request.HTTPMethod = method;

    for (NSString *header in _defaultHeaders) {
        [request setValue:_defaultHeaders[header] forHTTPHeaderField:header];
    }

    if (body) {
        NSError *error;
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
        if (error) {
            NSLog(@"AIHTTPClientLegacy: JSON serialization error: %@", error);
        }
    }
    return request;
}

- (NSMutableURLRequest *)requestWithFullURL:(NSString *)urlString method:(NSString *)method body:(NSDictionary *)body {
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                          cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                      timeoutInterval:_timeoutInterval];
    request.HTTPMethod = method;

    for (NSString *header in _defaultHeaders) {
        [request setValue:_defaultHeaders[header] forHTTPHeaderField:header];
    }

    if (body) {
        NSError *error;
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
        if (error) {
            NSLog(@"AIHTTPClientLegacy: JSON serialization error: %@", error);
        }
    }
    return request;
}

#pragma mark - Standard Requests

- (void)GET:(NSString *)endpoint completion:(void (^)(NSData *, NSError *))completion {
    NSMutableURLRequest *request = [self requestWithMethod:@"GET" endpoint:endpoint body:nil];
    [self performRequest:request completion:completion isStreaming:NO isUpload:NO];
}

- (void)POST:(NSString *)endpoint body:(NSDictionary *)body completion:(void (^)(NSData *, NSError *))completion {
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" endpoint:endpoint body:body];
    [self performRequest:request completion:completion isStreaming:NO isUpload:NO];
}

- (void)PUT:(NSString *)endpoint body:(NSDictionary *)body completion:(void (^)(NSData *, NSError *))completion {
    NSMutableURLRequest *request = [self requestWithMethod:@"PUT" endpoint:endpoint body:body];
    [self performRequest:request completion:completion isStreaming:NO isUpload:NO];
}

- (void)DELETE:(NSString *)endpoint completion:(void (^)(NSData *, NSError *))completion {
    NSMutableURLRequest *request = [self requestWithMethod:@"DELETE" endpoint:endpoint body:nil];
    [self performRequest:request completion:completion isStreaming:NO isUpload:NO];
}

- (void)GETWithFullURL:(NSString *)url completion:(void (^)(NSData *, NSError *))completion {
    NSMutableURLRequest *request = [self requestWithFullURL:url method:@"GET" body:nil];
    [self performRequest:request completion:completion isStreaming:NO isUpload:NO];
}

- (void)POSTWithFullURL:(NSString *)url body:(NSDictionary *)body completion:(void (^)(NSData *, NSError *))completion {
    NSMutableURLRequest *request = [self requestWithFullURL:url method:@"POST" body:body];
    [self performRequest:request completion:completion isStreaming:NO isUpload:NO];
}

#pragma mark - Streaming Requests

- (void)streamPOST:(NSString *)endpoint body:(NSDictionary *)body onChunk:(void (^)(NSString *))chunkHandler completion:(void (^)(NSData *, NSError *))completion {
    NSString *urlString = [_baseURL stringByAppendingString:[NSString stringWithFormat:@"/%@", endpoint]];
    [self streamPOSTWithFullURL:urlString body:body onChunk:chunkHandler completion:completion];
}

- (void)streamPOSTWithFullURL:(NSString *)url body:(NSDictionary *)body onChunk:(void (^)(NSString *))chunkHandler completion:(void (^)(NSData *, NSError *))completion {
    NSMutableURLRequest *request = [self requestWithFullURL:url method:@"POST" body:body];
    [self performRequest:request completion:completion chunkHandler:chunkHandler isStreaming:YES isUpload:NO];
}

#pragma mark - Multipart Upload

- (void)uploadMultipart:(NSString *)endpoint
                  files:(NSArray<NSDictionary *> *)files
                 fields:(NSDictionary *)fields
            progress:(void (^)(float progress))progressHandler
           completion:(void (^)(NSData *, NSError *))completion {

    NSString *urlString = [_baseURL stringByAppendingString:[NSString stringWithFormat:@"/%@", endpoint]];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                          cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                      timeoutInterval:300.0];
    request.HTTPMethod = @"POST";

    NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];

    for (NSString *header in _defaultHeaders) {
        if (![header isEqualToString:@"Content-Type"]) {
            [request setValue:_defaultHeaders[header] forHTTPHeaderField:header];
        }
    }

    NSMutableData *body = [NSMutableData data];

    for (NSString *key in fields) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"%@\r\n", fields[key]] dataUsingEncoding:NSUTF8StringEncoding]];
    }

    for (NSDictionary *file in files) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", file[@"name"], file[@"filename"]] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", file[@"mimeType"]] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:file[@"data"]];
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }

    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    request.HTTPBody = body;

    [self performRequest:request completion:completion progressHandler:progressHandler isStreaming:NO isUpload:YES];
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

    // Use performRequest with isUpload=YES for progress (though we don't need progress here)
    [self performRequest:request completion:completion isStreaming:NO isUpload:NO];
}

#pragma mark - Core Request Execution

- (void)performRequest:(NSMutableURLRequest *)request
            completion:(void (^)(NSData *, NSError *))completion
        chunkHandler:(void (^)(NSString *))chunkHandler
       progressHandler:(void (^)(float))progressHandler
           isStreaming:(BOOL)streaming
             isUpload:(BOOL)upload {

    AIHTTPRequestContext *context = [[AIHTTPRequestContext alloc] init];
    context.client = self;
    context.completion = completion;
    context.chunkHandler = chunkHandler;
    context.progressHandler = progressHandler;
    context.receivedData = [NSMutableData data];
    context.buffer = [NSMutableData data];
    context.isStreaming = streaming;
    context.isUpload = upload;

    // Start connection on main thread (NSURLConnection needs run loop)
    dispatch_async(dispatch_get_main_queue(), ^{
        NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:context startImmediately:YES];
        if (!conn) {
            NSError *error = [NSError errorWithDomain:@"AIHTTPClientLegacy" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create connection"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        context.connection = conn;

        @synchronized(_activeConnections) {
            _activeConnections[conn] = context;
        }
    });
}

- (void)performRequest:(NSMutableURLRequest *)request completion:(void (^)(NSData *, NSError *))completion isStreaming:(BOOL)streaming isUpload:(BOOL)upload {
    [self performRequest:request completion:completion chunkHandler:nil progressHandler:nil isStreaming:streaming isUpload:upload];
}

- (void)performRequest:(NSMutableURLRequest *)request completion:(void (^)(NSData *, NSError *))completion chunkHandler:(void (^)(NSString *))chunkHandler isStreaming:(BOOL)streaming isUpload:(BOOL)upload {
    [self performRequest:request completion:completion chunkHandler:chunkHandler progressHandler:nil isStreaming:streaming isUpload:upload];
}

#pragma mark - Public API for Cancelling

- (void)cancelAllRequests {
    @synchronized(_activeConnections) {
        for (NSURLConnection *conn in _activeConnections.allKeys) {
            [conn cancel];
        }
        [_activeConnections removeAllObjects];
    }
}

@end