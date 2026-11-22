//
//  AIFileManager.h
//  AIClient
//

#import <Foundation/Foundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface AIFileManager : NSObject

+ (instancetype)sharedManager;

// File operations
- (BOOL)saveData:(NSData *)data toFile:(NSString *)fileName error:(NSError **)error;
- (NSData *)loadDataFromFile:(NSString *)fileName error:(NSError **)error;
- (BOOL)deleteFile:(NSString *)fileName error:(NSError **)error;
- (BOOL)fileExists:(NSString *)fileName;
- (NSArray<NSString *> *)listFilesInDirectory:(NSString *)directory error:(NSError **)error;

// App directories
- (NSString *)documentsPath;
- (NSString *)cachesPath;
- (NSString *)tmpPath;
- (NSString *)appGroupContainerPath;

// Image handling
- (BOOL)saveImage:(UIImage *)image asFileName:(NSString *)fileName format:(NSString *)format error:(NSError **)error;
- (UIImage *)loadImageFromFile:(NSString *)fileName error:(NSError **)error;

// MIME/UTI
+ (NSString *)mimeTypeForPath:(NSString *)path;
+ (NSString *)utiForPath:(NSString *)path;
+ (NSString *)fileExtensionForMIMEType:(NSString *)mimeType;

// File size formatting
+ (NSString *)formattedFileSize:(unsigned long long)bytes;

@end