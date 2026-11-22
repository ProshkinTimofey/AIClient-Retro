//
//  AIAttachment.h
//  AIClient
//
//  Attachment model for images, documents, and other files.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

typedef NS_ENUM(NSUInteger, AIAttachmentType) {
    AIAttachmentTypeImage = 0,
    AIAttachmentTypeDocument,
    AIAttachmentTypeAudio,
    AIAttachmentTypeVideo,
    AIAttachmentTypeData
};

typedef NS_ENUM(NSUInteger, AIAttachmentSource) {
    AIAttachmentSourceLocal = 0,      // Local file path
    AIAttachmentSourceRemote,         // Remote URL (already uploaded)
    AIAttachmentSourceBase64,         // Inline base64 data
    AIAttachmentSourceProviderFileID  // Provider-specific file ID (e.g., OpenAI file_id)
};

@interface AIAttachment : NSObject <NSCopying, NSCoding>

// Identification
@property (nonatomic, copy) NSString *attachmentID;
@property (nonatomic, assign) AIAttachmentType type;
@property (nonatomic, assign) AIAttachmentSource source;

// File info
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *mimeType;
@property (nonatomic, assign) unsigned long long fileSize;
@property (nonatomic, copy) NSString *utiType; // Uniform Type Identifier

// Source-specific data
@property (nonatomic, copy) NSString *localPath;        // For AIAttachmentSourceLocal
@property (nonatomic, copy) NSString *remoteURL;        // For AIAttachmentSourceRemote
@property (nonatomic, copy) NSString *base64Data;       // For AIAttachmentSourceBase64
@property (nonatomic, copy) NSString *providerFileID;   // For AIAttachmentSourceProviderFileID
@property (nonatomic, copy) NSString *providerType;     // e.g., "openai", "anthropic", "gemini"

// Image-specific
@property (nonatomic, assign) CGSize pixelSize;
@property (nonatomic, strong) UIImage *thumbnail;       // Cached thumbnail

// Status
@property (nonatomic, assign) BOOL isUploaded;
@property (nonatomic, assign) BOOL isUploading;
@property (nonatomic, assign) float uploadProgress;
@property (nonatomic, copy) NSString *uploadError;

// Initializers
- (instancetype)initWithLocalPath:(NSString *)path;
- (instancetype)initWithRemoteURL:(NSString *)url mimeType:(NSString *)mimeType;
- (instancetype)initWithBase64Data:(NSString *)base64 mimeType:(NSString *)mimeType fileName:(NSString *)name;
- (instancetype)initWithProviderFileID:(NSString *)fileID provider:(NSString *)provider mimeType:(NSString *)mimeType;

// Factory methods
+ (instancetype)attachmentWithImage:(UIImage *)image fileName:(NSString *)name;
+ (instancetype)attachmentWithImageData:(NSData *)data fileName:(NSString *)name mimeType:(NSString *)mimeType;
+ (instancetype)attachmentWithDocumentAtPath:(NSString *)path;
+ (instancetype)attachmentWithDocumentData:(NSData *)data fileName:(NSString *)name mimeType:(NSString *)mimeType;

// Type detection
+ (AIAttachmentType)typeForUTI:(NSString *)uti;
+ (AIAttachmentType)typeForMIMEType:(NSString *)mimeType;
+ (NSString *)mimeTypeForUTI:(NSString *)uti;
+ (NSString *)utiForMIMEType:(NSString *)mimeType;

// Image handling
- (UIImage *)loadImage;
- (NSData *)loadImageData;
- (void)generateThumbnailWithSize:(CGSize)size completion:(void (^)(UIImage *thumbnail))completion;

// File handling
- (NSData *)loadFileData;
- (BOOL)isImage;
- (BOOL)isDocument;
- (BOOL)isSupportedForProvider:(NSString *)providerType;

// Serialization
- (NSDictionary *)dictionaryRepresentation;
+ (instancetype)attachmentFromDictionary:(NSDictionary *)dict;

// Validation
- (BOOL)validateForUpload:(NSError **)error;
- (BOOL)isValidForProvider:(NSString *)providerType error:(NSError **)error;

@end