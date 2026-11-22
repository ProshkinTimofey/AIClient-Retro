//
//  AIFileManager.m
//  AIClient
//

#import "AIFileManager.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static AIFileManager *_sharedManager = nil;

@implementation AIFileManager

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[self alloc] init];
    });
    return _sharedManager;
}

#pragma mark - Directories

- (NSString *)documentsPath {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
}

- (NSString *)cachesPath {
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
}

- (NSString *)tmpPath {
    return NSTemporaryDirectory();
}

- (NSString *)appGroupContainerPath {
    NSURL *url = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.ai.client"];
    return url.path;
}

#pragma mark - File Operations

- (NSString *)fullPathForFile:(NSString *)fileName {
    return [self.documentsPath stringByAppendingPathComponent:fileName];
}

- (BOOL)saveData:(NSData *)data toFile:(NSString *)fileName error:(NSError **)error {
    NSString *path = [self fullPathForFile:fileName];
    return [data writeToFile:path options:NSDataWritingAtomic error:error];
}

- (NSData *)loadDataFromFile:(NSString *)fileName error:(NSError **)error {
    NSString *path = [self fullPathForFile:fileName];
    return [NSData dataWithContentsOfFile:path options:0 error:error];
}

- (BOOL)deleteFile:(NSString *)fileName error:(NSError **)error {
    NSString *path = [self fullPathForFile:fileName];
    return [[NSFileManager defaultManager] removeItemAtPath:path error:error];
}

- (BOOL)fileExists:(NSString *)fileName {
    NSString *path = [self fullPathForFile:fileName];
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (NSArray<NSString *> *)listFilesInDirectory:(NSString *)directory error:(NSError **)error {
    NSString *path = [self.documentsPath stringByAppendingPathComponent:directory];
    return [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:error];
}

#pragma mark - Image Handling

- (BOOL)saveImage:(UIImage *)image asFileName:(NSString *)fileName format:(NSString *)format error:(NSError **)error {
    NSData *data = nil;
    if ([format isEqualToString:@"png"]) {
        data = UIImagePNGRepresentation(image);
    } else if ([format isEqualToString:@"jpeg"] || [format isEqualToString:@"jpg"]) {
        data = UIImageJPEGRepresentation(image, 0.9);
    } else if ([format isEqualToString:@"heic"]) {
        // HEIC not directly supported, use JPEG
        data = UIImageJPEGRepresentation(image, 0.9);
    }
    if (!data) {
        if (error) *error = [NSError errorWithDomain:@"AIFileManager" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to encode image"}];
        return NO;
    }
    return [self saveData:data toFile:fileName error:error];
}

- (UIImage *)loadImageFromFile:(NSString *)fileName error:(NSError **)error {
    NSData *data = [self loadDataFromFile:fileName error:error];
    if (!data) return nil;
    return [UIImage imageWithData:data];
}

#pragma mark - MIME/UTI

+ (NSString *)mimeTypeForPath:(NSString *)path {
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[path pathExtension], NULL);
    if (!uti) return @"application/octet-stream";
    CFStringRef mime = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType);
    CFRelease(uti);
    NSString *result = (__bridge_transfer NSString *)mime;
    return result ?: @"application/octet-stream";
}

+ (NSString *)utiForPath:(NSString *)path {
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[path pathExtension], NULL);
    NSString *result = (__bridge_transfer NSString *)uti;
    return result ?: @"public.data";
}

+ (NSString *)fileExtensionForMIMEType:(NSString *)mimeType {
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)mimeType, NULL);
    if (!uti) return @"bin";
    CFStringRef ext = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
    CFRelease(uti);
    NSString *result = (__bridge_transfer NSString *)ext;
    return result ?: @"bin";
}

#pragma mark - Formatting

+ (NSString *)formattedFileSize:(unsigned long long)bytes {
    if (bytes < 1024) return [NSString stringWithFormat:@"%llu B", bytes];
    if (bytes < 1024 * 1024) return [NSString stringWithFormat:@"%.1f KB", (double)bytes / 1024];
    if (bytes < 1024 * 1024 * 1024) return [NSString stringWithFormat:@"%.1f MB", (double)bytes / (1024 * 1024)];
    return [NSString stringWithFormat:@"%.1f GB", (double)bytes / (1024 * 1024 * 1024)];
}

@end