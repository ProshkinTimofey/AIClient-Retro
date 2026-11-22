//
//  AIAttachment.m
//  AIClient
//

#import "AIAttachment.h"
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSUInteger _attachmentIDCounter = 0;

@implementation AIAttachment

- (instancetype)initWithLocalPath:(NSString *)path {
    self = [super init];
    if (self) {
        _attachmentID = [NSString stringWithFormat:@"att_%llu_%lu", (unsigned long long)[[NSDate date] timeIntervalSince1970 * 1000], (unsigned long)OSAtomicIncrement64(&_attachmentIDCounter)];
        _source = AIAttachmentSourceLocal;
        _localPath = path;
        _fileName = [path lastPathComponent];
        _utiType = [self utiForPath:path];
        _mimeType = [self mimeTypeForUTI:_utiType];
        _type = [AIAttachment typeForUTI:_utiType];
        _isUploaded = NO;
        _isUploading = NO;
        _uploadProgress = 0.0f;

        NSFileManager *fm = [NSFileManager defaultManager];
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
        _fileSize = [attrs[NSFileSize] unsignedLongLongValue];

        if (_type == AIAttachmentTypeImage) {
            [self loadImageInfo];
        }
    }
    return self;
}

- (instancetype)initWithRemoteURL:(NSString *)url mimeType:(NSString *)mimeType {
    self = [super init];
    if (self) {
        _attachmentID = [NSString stringWithFormat:@"att_%llu_%lu", (unsigned long long)[[NSDate date] timeIntervalSince1970 * 1000], (unsigned long)OSAtomicIncrement64(&_attachmentIDCounter)];
        _source = AIAttachmentSourceRemote;
        _remoteURL = url;
        _mimeType = mimeType;
        _utiType = [self utiForMIMEType:mimeType];
        _type = [AIAttachment typeForMIMEType:mimeType];
        _fileName = [url lastPathComponent];
        _isUploaded = YES;
    }
    return self;
}

- (instancetype)initWithBase64Data:(NSString *)base64 mimeType:(NSString *)mimeType fileName:(NSString *)name {
    self = [super init];
    if (self) {
        _attachmentID = [NSString stringWithFormat:@"att_%llu_%lu", (unsigned long long)[[NSDate date] timeIntervalSince1970 * 1000], (unsigned long)OSAtomicIncrement64(&_attachmentIDCounter)];
        _source = AIAttachmentSourceBase64;
        _base64Data = base64;
        _mimeType = mimeType;
        _utiType = [self utiForMIMEType:mimeType];
        _type = [AIAttachment typeForMIMEType:mimeType];
        _fileName = name ?: [NSString stringWithFormat:@"file.%@", [self fileExtensionForMIMEType:mimeType]];
        _fileSize = (unsigned long long)(base64.length * 3 / 4);
        _isUploaded = YES;
    }
    return self;
}

- (instancetype)initWithProviderFileID:(NSString *)fileID provider:(NSString *)provider mimeType:(NSString *)mimeType {
    self = [super init];
    if (self) {
        _attachmentID = [NSString stringWithFormat:@"att_%llu_%lu", (unsigned long long)[[NSDate date] timeIntervalSince1970 * 1000], (unsigned long)OSAtomicIncrement64(&_attachmentIDCounter)];
        _source = AIAttachmentSourceProviderFileID;
        _providerFileID = fileID;
        _providerType = provider;
        _mimeType = mimeType;
        _utiType = [self utiForMIMEType:mimeType];
        _type = [AIAttachment typeForMIMEType:mimeType];
        _isUploaded = YES;
    }
    return self;
}

+ (instancetype)attachmentWithImage:(UIImage *)image fileName:(NSString *)name {
    NSData *data = UIImagePNGRepresentation(image);
    return [self attachmentWithImageData:data fileName:name mimeType:@"image/png"];
}

+ (instancetype)attachmentWithImageData:(NSData *)data fileName:(NSString *)name mimeType:(NSString *)mimeType {
    NSString *base64 = [data base64EncodedStringWithOptions:0];
    return [[self alloc] initWithBase64Data:base64 mimeType:mimeType fileName:name];
}

+ (instancetype)attachmentWithDocumentAtPath:(NSString *)path {
    return [[self alloc] initWithLocalPath:path];
}

+ (instancetype)attachmentWithDocumentData:(NSData *)data fileName:(NSString *)name mimeType:(NSString *)mimeType {
    NSString *base64 = [data base64EncodedStringWithOptions:0];
    return [[self alloc] initWithBase64Data:base64 mimeType:mimeType fileName:name];
}

+ (AIAttachmentType)typeForUTI:(NSString *)uti {
    if (!uti) return AIAttachmentTypeData;
    if ([uti hasPrefix:@"public.image"] || [UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeImage)]) return AIAttachmentTypeImage;
    if ([UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeAudio)]) return AIAttachmentTypeAudio;
    if ([UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeMovie)]) return AIAttachmentTypeVideo;
    if ([UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeContent)]) return AIAttachmentTypeDocument;
    return AIAttachmentTypeData;
}

+ (AIAttachmentType)typeForMIMEType:(NSString *)mimeType {
    if (!mimeType) return AIAttachmentTypeData;
    if ([mimeType hasPrefix:@"image/"]) return AIAttachmentTypeImage;
    if ([mimeType hasPrefix:@"audio/"]) return AIAttachmentTypeAudio;
    if ([mimeType hasPrefix:@"video/"]) return AIAttachmentTypeVideo;
    if ([mimeType hasPrefix:@"application/"] || [mimeType hasPrefix:@"text/"]) return AIAttachmentTypeDocument;
    return AIAttachmentTypeData;
}

+ (NSString *)mimeTypeForUTI:(NSString *)uti {
    if (!uti) return @"application/octet-stream";
    CFStringRef mime = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)uti, kUTTagClassMIMEType);
    NSString *result = (__bridge_transfer NSString *)mime;
    return result ?: @"application/octet-stream";
}

+ (NSString *)utiForMIMEType:(NSString *)mimeType {
    if (!mimeType) return @"public.data";
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)mimeType, NULL);
    NSString *result = (__bridge_transfer NSString *)uti;
    return result ?: @"public.data";
}

- (NSString *)utiForPath:(NSString *)path {
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[path pathExtension], NULL);
    NSString *result = (__bridge_transfer NSString *)uti;
    return result ?: @"public.data";
}

- (NSString *)fileExtensionForMIMEType:(NSString *)mimeType {
    CFStringRef ext = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)[self utiForMIMEType:mimeType], kUTTagClassFilenameExtension);
    return (__bridge_transfer NSString *)ext ?: @"bin";
}

- (void)loadImageInfo {
    if (_source != AIAttachmentSourceLocal) return;

    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:_localPath], NULL);
    if (source) {
        CFDictionaryRef props = CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
        if (props) {
            NSNumber *width = (__bridge NSNumber *)CFDictionaryGetValue(props, kCGImagePropertyPixelWidth);
            NSNumber *height = (__bridge NSNumber *)CFDictionaryGetValue(props, kCGImagePropertyPixelHeight);
            if (width && height) {
                _pixelSize = CGSizeMake([width doubleValue], [height doubleValue]);
            }
            CFRelease(props);
        }
        CFRelease(source);
    }
}

- (UIImage *)loadImage {
    if (_source == AIAttachmentSourceLocal) {
        return [UIImage imageWithContentsOfFile:_localPath];
    } else if (_source == AIAttachmentSourceBase64) {
        NSData *data = [[NSData alloc] initWithBase64EncodedString:_base64Data options:0];
        return [UIImage imageWithData:data];
    } else if (_source == AIAttachmentSourceRemote) {
        // Would need async download
        return nil;
    }
    return nil;
}

- (NSData *)loadImageData {
    if (_source == AIAttachmentSourceLocal) {
        return [NSData dataWithContentsOfFile:_localPath];
    } else if (_source == AIAttachmentSourceBase64) {
        return [[NSData alloc] initWithBase64EncodedString:_base64Data options:0];
    }
    return nil;
}

- (NSData *)loadFileData {
    if (_source == AIAttachmentSourceLocal) {
        return [NSData dataWithContentsOfFile:_localPath];
    } else if (_source == AIAttachmentSourceBase64) {
        return [[NSData alloc] initWithBase64EncodedString:_base64Data options:0];
    }
    return nil;
}

- (void)generateThumbnailWithSize:(CGSize)size completion:(void (^)(UIImage *))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *image = [self loadImage];
        UIImage *thumb = nil;
        if (image) {
            UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
            [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
            thumb = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(thumb);
        });
    });
}

- (BOOL)isImage {
    return _type == AIAttachmentTypeImage;
}

- (BOOL)isDocument {
    return _type == AIAttachmentTypeDocument;
}

- (BOOL)isSupportedForProvider:(NSString *)providerType {
    if ([providerType isEqualToString:@"openai"]) {
        // OpenAI supports images (vision), PDFs, text files
        return _type == AIAttachmentTypeImage || _type == AIAttachmentTypeDocument;
    } else if ([providerType isEqualToString:@"anthropic"]) {
        // Anthropic supports images, PDFs, text
        return _type == AIAttachmentTypeImage || _type == AIAttachmentTypeDocument;
    } else if ([providerType isEqualToString:@"gemini"]) {
        // Gemini supports images, PDFs, audio, video, text
        return _type != AIAttachmentTypeData;
    }
    return YES;
}

- (BOOL)validateForUpload:(NSError **)error {
    if (_source != AIAttachmentSourceLocal) {
        if (error) *error = [NSError errorWithDomain:@"AIAttachment" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Only local files can be uploaded"}];
        return NO;
    }
    if (_fileSize > 50 * 1024 * 1024) { // 50MB limit
        if (error) *error = [NSError errorWithDomain:@"AIAttachment" code:2 userInfo:@{NSLocalizedDescriptionKey: @"File too large (max 50MB)"}];
        return NO;
    }
    return YES;
}

- (BOOL)isValidForProvider:(NSString *)providerType error:(NSError **)error {
    if (![self isSupportedForProvider:providerType]) {
        if (error) *error = [NSError errorWithDomain:@"AIAttachment" code:3 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Attachment type not supported by %@", providerType]}];
        return NO;
    }
    return [self validateForUpload:error];
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"attachmentID"] = _attachmentID;
    dict[@"type"] = @(_type);
    dict[@"source"] = @(_source);
    dict[@"fileName"] = _fileName;
    dict[@"mimeType"] = _mimeType;
    dict[@"fileSize"] = @(_fileSize);
    dict[@"utiType"] = _utiType;
    dict[@"localPath"] = _localPath;
    dict[@"remoteURL"] = _remoteURL;
    dict[@"base64Data"] = _base64Data;
    dict[@"providerFileID"] = _providerFileID;
    dict[@"providerType"] = _providerType;
    dict[@"pixelSize"] = NSStringFromCGSize(_pixelSize);
    dict[@"isUploaded"] = @(_isUploaded);
    return [dict copy];
}

+ (instancetype)attachmentFromDictionary:(NSDictionary *)dict {
    AIAttachmentSource source = [dict[@"source"] unsignedIntegerValue];
    AIAttachment *att = nil;

    switch (source) {
        case AIAttachmentSourceLocal:
            att = [[self alloc] initWithLocalPath:dict[@"localPath"]];
            break;
        case AIAttachmentSourceRemote:
            att = [[self alloc] initWithRemoteURL:dict[@"remoteURL"] mimeType:dict[@"mimeType"]];
            break;
        case AIAttachmentSourceBase64:
            att = [[self alloc] initWithBase64Data:dict[@"base64Data"] mimeType:dict[@"mimeType"] fileName:dict[@"fileName"]];
            break;
        case AIAttachmentSourceProviderFileID:
            att = [[self alloc] initWithProviderFileID:dict[@"providerFileID"] provider:dict[@"providerType"] mimeType:dict[@"mimeType"]];
            break;
    }

    if (att) {
        att.attachmentID = dict[@"attachmentID"];
        att.fileName = dict[@"fileName"];
        att.fileSize = [dict[@"fileSize"] unsignedLongLongValue];
        att.isUploaded = [dict[@"isUploaded"] boolValue];
    }
    return att;
}

- (id)copyWithZone:(NSZone *)zone {
    AIAttachment *copy = [[[self class] allocWithZone:zone] init];
    copy.attachmentID = _attachmentID;
    copy.type = _type;
    copy.source = _source;
    copy.fileName = _fileName;
    copy.mimeType = _mimeType;
    copy.fileSize = _fileSize;
    copy.utiType = _utiType;
    copy.localPath = _localPath;
    copy.remoteURL = _remoteURL;
    copy.base64Data = _base64Data;
    copy.providerFileID = _providerFileID;
    copy.providerType = _providerType;
    copy.pixelSize = _pixelSize;
    copy.thumbnail = _thumbnail;
    copy.isUploaded = _isUploaded;
    copy.isUploading = _isUploading;
    copy.uploadProgress = _uploadProgress;
    copy.uploadError = _uploadError;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_attachmentID forKey:@"attachmentID"];
    [coder encodeInteger:_type forKey:@"type"];
    [coder encodeInteger:_source forKey:@"source"];
    [coder encodeObject:_fileName forKey:@"fileName"];
    [coder encodeObject:_mimeType forKey:@"mimeType"];
    [coder encodeUnsignedLongLong:_fileSize forKey:@"fileSize"];
    [coder encodeObject:_utiType forKey:@"utiType"];
    [coder encodeObject:_localPath forKey:@"localPath"];
    [coder encodeObject:_remoteURL forKey:@"remoteURL"];
    [coder encodeObject:_base64Data forKey:@"base64Data"];
    [coder encodeObject:_providerFileID forKey:@"providerFileID"];
    [coder encodeObject:_providerType forKey:@"providerType"];
    [coder encodeCGSize:_pixelSize forKey:@"pixelSize"];
    [coder encodeObject:_thumbnail forKey:@"thumbnail"];
    [coder encodeBool:_isUploaded forKey:@"isUploaded"];
    [coder encodeBool:_isUploading forKey:@"isUploading"];
    [coder encodeFloat:_uploadProgress forKey:@"uploadProgress"];
    [coder encodeObject:_uploadError forKey:@"uploadError"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _attachmentID = [coder decodeObjectForKey:@"attachmentID"];
        _type = [coder decodeIntegerForKey:@"type"];
        _source = [coder decodeIntegerForKey:@"source"];
        _fileName = [coder decodeObjectForKey:@"fileName"];
        _mimeType = [coder decodeObjectForKey:@"mimeType"];
        _fileSize = [coder decodeUnsignedLongLongForKey:@"fileSize"];
        _utiType = [coder decodeObjectForKey:@"utiType"];
        _localPath = [coder decodeObjectForKey:@"localPath"];
        _remoteURL = [coder decodeObjectForKey:@"remoteURL"];
        _base64Data = [coder decodeObjectForKey:@"base64Data"];
        _providerFileID = [coder decodeObjectForKey:@"providerFileID"];
        _providerType = [coder decodeObjectForKey:@"providerType"];
        _pixelSize = [coder decodeCGSizeForKey:@"pixelSize"];
        _thumbnail = [coder decodeObjectForKey:@"thumbnail"];
        _isUploaded = [coder decodeBoolForKey:@"isUploaded"];
        _isUploading = [coder decodeBoolForKey:@"isUploading"];
        _uploadProgress = [coder decodeFloatForKey:@"uploadProgress"];
        _uploadError = [coder decodeObjectForKey:@"uploadError"];
    }
    return self;
}

@end