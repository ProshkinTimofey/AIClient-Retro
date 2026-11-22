//
//  AIMessage.m
//  AIClient
//

#import "AIMessage.h"
#import "AIAttachment.h"

static NSUInteger _messageIDCounter = 0;

@implementation AIMessage

- (instancetype)initWithRole:(AIMessageRole)role content:(NSString *)content {
    self = [super init];
    if (self) {
        _messageID = [NSString stringWithFormat:@"msg_%llu_%lu", (unsigned long long)[[NSDate date] timeIntervalSince1970 * 1000], (unsigned long)OSAtomicIncrement64(&_messageIDCounter)];
        _role = role;
        _content = content ? content : @"";
        _attachments = @[];
        _status = AIMessageStatusSending;
        _timestamp = [NSDate date];
        _tokenCount = 0;
        _metadata = @{};
    }
    return self;
}

- (instancetype)initWithRole:(AIMessageRole)role content:(NSString *)content attachments:(NSArray<AIAttachment *> *)attachments {
    self = [self initWithRole:role content:content];
    if (self) {
        _attachments = attachments ? attachments : @[];
    }
    return self;
}

+ (instancetype)systemMessage:(NSString *)content {
    return [[self alloc] initWithRole:AIMessageRoleSystem content:content];
}

+ (instancetype)userMessage:(NSString *)content {
    return [[self alloc] initWithRole:AIMessageRoleUser content:content];
}

+ (instancetype)userMessage:(NSString *)content attachments:(NSArray<AIAttachment *> *)attachments {
    return [[self alloc] initWithRole:AIMessageRoleUser content:content attachments:attachments];
}

+ (instancetype)assistantMessage:(NSString *)content {
    return [[self alloc] initWithRole:AIMessageRoleAssistant content:content];
}

+ (instancetype)toolMessage:(NSString *)toolCallID name:(NSString *)name result:(NSString *)result {
    AIMessage *msg = [[self alloc] initWithRole:AIMessageRoleTool content:result];
    msg.toolCallID = toolCallID;
    msg.toolName = name;
    msg.status = AIMessageStatusComplete;
    return msg;
}

- (BOOL)hasTextContent {
    return self.content.length > 0;
}

- (BOOL)hasAttachments {
    return self.attachments.count > 0;
}

- (BOOL)hasImages {
    return [self imageAttachments].count > 0;
}

- (BOOL)hasFiles {
    return [self fileAttachments].count > 0;
}

- (NSArray<AIAttachment *> *)imageAttachments {
    return [self.attachments filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(AIAttachment *att, NSDictionary *bindings) {
        return att.type == AIAttachmentTypeImage;
    }]];
}

- (NSArray<AIAttachment *> *)fileAttachments {
    return [self.attachments filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(AIAttachment *att, NSDictionary *bindings) {
        return att.type != AIAttachmentTypeImage;
    }]];
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"messageID"] = _messageID;
    dict[@"role"] = @(_role);
    dict[@"content"] = _content;
    dict[@"status"] = @(_status);
    dict[@"timestamp"] = _timestamp;
    dict[@"model"] = _model;
    dict[@"tokenCount"] = @(_tokenCount);
    dict[@"toolCallID"] = _toolCallID;
    dict[@"toolName"] = _toolName;
    dict[@"toolArguments"] = _toolArguments;
    dict[@"toolResult"] = _toolResult;
    dict[@"metadata"] = _metadata;
    dict[@"errorMessage"] = _errorMessage;

    NSMutableArray *attachmentsArray = [NSMutableArray array];
    for (AIAttachment *att in _attachments) {
        [attachmentsArray addObject:[att dictionaryRepresentation]];
    }
    dict[@"attachments"] = attachmentsArray;

    return [dict copy];
}

+ (instancetype)messageFromDictionary:(NSDictionary *)dict {
    AIMessageRole role = [dict[@"role"] unsignedIntegerValue];
    AIMessage *msg = [[self alloc] initWithRole:role content:dict[@"content"]];
    msg.messageID = dict[@"messageID"];
    msg.status = [dict[@"status"] unsignedIntegerValue];
    msg.timestamp = dict[@"timestamp"];
    msg.model = dict[@"model"];
    msg.tokenCount = [dict[@"tokenCount"] unsignedIntegerValue];
    msg.toolCallID = dict[@"toolCallID"];
    msg.toolName = dict[@"toolName"];
    msg.toolArguments = dict[@"toolArguments"];
    msg.toolResult = dict[@"toolResult"];
    msg.metadata = dict[@"metadata"] ?: @{};
    msg.errorMessage = dict[@"errorMessage"];

    NSMutableArray *attachments = [NSMutableArray array];
    for (NSDictionary *attDict in dict[@"attachments"] ?: @[]) {
        AIAttachment *att = [AIAttachment attachmentFromDictionary:attDict];
        if (att) [attachments addObject:att];
    }
    msg.attachments = attachments;

    return msg;
}

- (id)copyWithZone:(NSZone *)zone {
    AIMessage *copy = [[[self class] allocWithZone:zone] initWithRole:_role content:_content attachments:_attachments];
    copy.messageID = _messageID;
    copy.status = _status;
    copy.timestamp = _timestamp;
    copy.model = _model;
    copy.tokenCount = _tokenCount;
    copy.toolCallID = _toolCallID;
    copy.toolName = _toolName;
    copy.toolArguments = _toolArguments;
    copy.toolResult = _toolResult;
    copy.metadata = _metadata;
    copy.errorMessage = _errorMessage;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_messageID forKey:@"messageID"];
    [coder encodeInteger:_role forKey:@"role"];
    [coder encodeObject:_content forKey:@"content"];
    [coder encodeObject:_attachments forKey:@"attachments"];
    [coder encodeInteger:_status forKey:@"status"];
    [coder encodeObject:_timestamp forKey:@"timestamp"];
    [coder encodeObject:_model forKey:@"model"];
    [coder encodeInteger:_tokenCount forKey:@"tokenCount"];
    [coder encodeObject:_toolCallID forKey:@"toolCallID"];
    [coder encodeObject:_toolName forKey:@"toolName"];
    [coder encodeObject:_toolArguments forKey:@"toolArguments"];
    [coder encodeObject:_toolResult forKey:@"toolResult"];
    [coder encodeObject:_metadata forKey:@"metadata"];
    [coder encodeObject:_errorMessage forKey:@"errorMessage"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _messageID = [coder decodeObjectForKey:@"messageID"];
        _role = [coder decodeIntegerForKey:@"role"];
        _content = [coder decodeObjectForKey:@"content"];
        _attachments = [coder decodeObjectForKey:@"attachments"];
        _status = [coder decodeIntegerForKey:@"status"];
        _timestamp = [coder decodeObjectForKey:@"timestamp"];
        _model = [coder decodeObjectForKey:@"model"];
        _tokenCount = [coder decodeIntegerForKey:@"tokenCount"];
        _toolCallID = [coder decodeObjectForKey:@"toolCallID"];
        _toolName = [coder decodeObjectForKey:@"toolName"];
        _toolArguments = [coder decodeObjectForKey:@"toolArguments"];
        _toolResult = [coder decodeObjectForKey:@"toolResult"];
        _metadata = [coder decodeObjectForKey:@"metadata"];
        _errorMessage = [coder decodeObjectForKey:@"errorMessage"];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<AIMessage: %@ role=%lu status=%lu content=%@ attachments=%lu>", _messageID, (unsigned long)_role, (unsigned long)_status, _content.length > 50 ? [_content substringToIndex:50] : _content, (unsigned long)_attachments.count];
}

@end