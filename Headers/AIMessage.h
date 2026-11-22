//
//  AIMessage.h
//  AIClient
//
//  Message model for conversations.
//

#import <Foundation/Foundation.h>
#import "AIAttachment.h"

typedef NS_ENUM(NSUInteger, AIMessageRole) {
    AIMessageRoleSystem = 0,
    AIMessageRoleUser,
    AIMessageRoleAssistant,
    AIMessageRoleTool,
    AIMessageRoleFunction
};

typedef NS_ENUM(NSUInteger, AIMessageStatus) {
    AIMessageStatusSending = 0,
    AIMessageStatusSent,
    AIMessageStatusStreaming,
    AIMessageStatusComplete,
    AIMessageStatusFailed,
    AIMessageStatusCancelled
};

@interface AIMessage : NSObject <NSCopying, NSCoding>

// Core properties
@property (nonatomic, copy) NSString *messageID;           // Unique identifier
@property (nonatomic, assign) AIMessageRole role;          // System/User/Assistant/Tool
@property (nonatomic, copy) NSString *content;             // Text content
@property (nonatomic, strong) NSArray<AIAttachment *> *attachments; // Images, files
@property (nonatomic, assign) AIMessageStatus status;      // Current status
@property (nonatomic, strong) NSDate *timestamp;           // Creation time
@property (nonatomic, copy) NSString *model;               // Model used
@property (nonatomic, assign) NSUInteger tokenCount;       // Estimated tokens

// Tool use (for function calling)
@property (nonatomic, copy) NSString *toolCallID;         // For tool responses
@property (nonatomic, copy) NSString *toolName;           // Function name
@property (nonatomic, copy) NSDictionary *toolArguments;  // Function arguments
@property (nonatomic, copy) NSString *toolResult;         // Function result

// Metadata
@property (nonatomic, copy) NSDictionary *metadata;       // Provider-specific data
@property (nonatomic, copy) NSString *errorMessage;       // If status == Failed

// Initializers
- (instancetype)initWithRole:(AIMessageRole)role content:(NSString *)content;
- (instancetype)initWithRole:(AIMessageRole)role content:(NSString *)content attachments:(NSArray<AIAttachment *> *)attachments;

// Factory methods
+ (instancetype)systemMessage:(NSString *)content;
+ (instancetype)userMessage:(NSString *)content;
+ (instancetype)userMessage:(NSString *)content attachments:(NSArray<AIAttachment *> *)attachments;
+ (instancetype)assistantMessage:(NSString *)content;
+ (instancetype)toolMessage:(NSString *)toolCallID name:(NSString *)name result:(NSString *)result;

// Content helpers
- (BOOL)hasTextContent;
- (BOOL)hasAttachments;
- (BOOL)hasImages;
- (BOOL)hasFiles;
- (NSArray<AIAttachment *> *)imageAttachments;
- (NSArray<AIAttachment *> *)fileAttachments;

// Serialization
- (NSDictionary *)dictionaryRepresentation;
+ (instancetype)messageFromDictionary:(NSDictionary *)dict;

// Copying
- (id)copyWithZone:(NSZone *)zone;

// Description
- (NSString *)description;

@end