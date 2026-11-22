//
//  AIConversationManager.m
//  AIClient
//

#import "AIConversationManager.h"
#import "AIMessage.h"
#import "AIAttachment.h"
#import "AISQLiteManager.h"

static AIConversationManager *_sharedManager = nil;
static const NSString *const kConversationsFile = @"conversations.json";

@implementation AIConversation

- (instancetype)initWithID:(NSString *)conversationID {
    self = [super init];
    if (self) {
        _conversationID = conversationID ?: [NSString stringWithFormat:@"conv_%llu", (unsigned long long)[[NSDate date] timeIntervalSince1970 * 1000]];
        _title = @"New Conversation";
        _createdAt = [NSDate date];
        _updatedAt = [NSDate date];
        _messages = @[];
        _temperature = 0.7;
        _maxTokens = 4096;
        _metadata = @{};
    }
    return self;
}

- (AIMessage *)lastMessage {
    return _messages.lastObject;
}

- (AIMessage *)lastUserMessage {
    for (NSInteger i = _messages.count - 1; i >= 0; i--) {
        AIMessage *msg = _messages[i];
        if (msg.role == AIMessageRoleUser) return msg;
    }
    return nil;
}

- (NSUInteger)messageCount {
    return _messages.count;
}

- (NSUInteger)estimatedTokenCount {
    NSUInteger count = 0;
    for (AIMessage *msg in _messages) {
        count += msg.tokenCount ?: (msg.content.length / 4);
    }
    return count;
}

- (id)copyWithZone:(NSZone *)zone {
    AIConversation *copy = [[[self class] allocWithZone:zone] initWithID:_conversationID];
    copy.title = _title;
    copy.createdAt = _createdAt;
    copy.updatedAt = _updatedAt;
    copy.messages = _messages;
    copy.systemPrompt = _systemPrompt;
    copy.model = _model;
    copy.temperature = _temperature;
    copy.maxTokens = _maxTokens;
    copy.metadata = _metadata;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_conversationID forKey:@"conversationID"];
    [coder encodeObject:_title forKey:@"title"];
    [coder encodeObject:_createdAt forKey:@"createdAt"];
    [coder encodeObject:_updatedAt forKey:@"updatedAt"];
    [coder encodeObject:_messages forKey:@"messages"];
    [coder encodeObject:_systemPrompt forKey:@"systemPrompt"];
    [coder encodeObject:_model forKey:@"model"];
    [coder encodeFloat:_temperature forKey:@"temperature"];
    [coder encodeInteger:_maxTokens forKey:@"maxTokens"];
    [coder encodeObject:_metadata forKey:@"metadata"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _conversationID = [coder decodeObjectForKey:@"conversationID"];
        _title = [coder decodeObjectForKey:@"title"];
        _createdAt = [coder decodeObjectForKey:@"createdAt"];
        _updatedAt = [coder decodeObjectForKey:@"updatedAt"];
        _messages = [coder decodeObjectForKey:@"messages"];
        _systemPrompt = [coder decodeObjectForKey:@"systemPrompt"];
        _model = [coder decodeObjectForKey:@"model"];
        _temperature = [coder decodeFloatForKey:@"temperature"];
        _maxTokens = [coder decodeIntegerForKey:@"maxTokens"];
        _metadata = [coder decodeObjectForKey:@"metadata"];
    }
    return self;
}

@end

@implementation AIConversationManager

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[self alloc] init];
    });
    return _sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _conversations = [NSMutableArray array];
        _currentConversation = nil;
        _hasUnsavedChanges = NO;
        [self loadAllConversations];
    }
    return self;
}

#pragma mark - Conversation Lifecycle

- (AIConversation *)createNewConversationWithTitle:(NSString *)title {
    return [self createNewConversationWithTitle:title systemPrompt:nil model:nil];
}

- (AIConversation *)createNewConversationWithTitle:(NSString *)title systemPrompt:(NSString *)systemPrompt model:(NSString *)model {
    AIConversation *conv = [[AIConversation alloc] initWithID:nil];
    conv.title = title ?: @"New Conversation";
    conv.systemPrompt = systemPrompt ?: _defaultSystemPrompt;
    conv.model = model ?: _defaultModel;
    conv.temperature = _defaultTemperature;
    conv.maxTokens = _defaultMaxTokens;

    [_conversations insertObject:conv atIndex:0];
    _currentConversation = conv;
    _hasUnsavedChanges = YES;

    if ([_delegate respondsToSelector:@selector(conversationManager:didCreateConversation:)]) {
        [_delegate conversationManager:self didCreateConversation:conv.conversationID];
    }

    [self saveAllConversations];
    return conv;
}

- (void)switchToConversation:(AIConversation *)conversation {
    if (_currentConversation != conversation) {
        _currentConversation = conversation;
        _hasUnsavedChanges = YES;
    }
}

- (void)deleteConversation:(AIConversation *)conversation completion:(void (^)(BOOL, NSError *))completion {
    [self deleteConversationWithID:conversation.conversationID completion:completion];
}

- (void)deleteConversationWithID:(NSString *)conversationID completion:(void (^)(BOOL, NSError *))completion {
    AIConversation *toDelete = nil;
    for (AIConversation *conv in _conversations) {
        if ([conv.conversationID isEqualToString:conversationID]) {
            toDelete = conv;
            break;
        }
    }

    if (!toDelete) {
        if (completion) completion(NO, [NSError errorWithDomain:@"AIConversationManager" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Conversation not found"}]);
        return;
    }

    [_conversations removeObject:toDelete];

    if (_currentConversation == toDelete) {
        _currentConversation = _conversations.firstObject;
    }

    _hasUnsavedChanges = YES;

    if ([_delegate respondsToSelector:@selector(conversationManager:didDeleteConversation:)]) {
        [_delegate conversationManager:self didDeleteConversation:conversationID];
    }

    [self saveAllConversations];
    if (completion) completion(YES, nil);
}

#pragma mark - Message Management

- (void)addMessage:(AIMessage *)message toConversation:(AIConversation *)conversation {
    NSMutableArray *messages = [conversation.messages mutableCopy];
    [messages addObject:message];
    conversation.messages = messages;
    conversation.updatedAt = [NSDate date];
    _hasUnsavedChanges = YES;

    if ([_delegate respondsToSelector:@selector(conversationManager:didAddMessage:toConversation:)]) {
        [_delegate conversationManager:self didAddMessage:message toConversation:conversation.conversationID];
    }
}

- (void)updateMessage:(AIMessage *)message inConversation:(AIConversation *)conversation {
    NSMutableArray *messages = [conversation.messages mutableCopy];
    NSUInteger index = [messages indexOfObjectPassingTest:^BOOL(AIMessage *msg, NSUInteger idx, BOOL *stop) {
        return [msg.messageID isEqualToString:message.messageID];
    }];
    if (index != NSNotFound) {
        messages[index] = message;
        conversation.messages = messages;
        conversation.updatedAt = [NSDate date];
        _hasUnsavedChanges = YES;

        if ([_delegate respondsToSelector:@selector(conversationManager:didUpdateMessage:inConversation:)]) {
            [_delegate conversationManager:self didUpdateMessage:message inConversation:conversation.conversationID];
        }
    }
}

- (void)removeMessage:(AIMessage *)message fromConversation:(AIConversation *)conversation {
    NSMutableArray *messages = [conversation.messages mutableCopy];
    [messages removeObject:message];
    conversation.messages = messages;
    conversation.updatedAt = [NSDate date];
    _hasUnsavedChanges = YES;
}

- (NSArray<AIMessage *> *)messagesForConversation:(AIConversation *)conversation {
    return conversation.messages;
}

- (NSArray<AIMessage *> *)recentMessagesForConversation:(AIConversation *)conversation limit:(NSUInteger)limit {
    NSUInteger count = conversation.messages.count;
    NSUInteger start = count > limit ? count - limit : 0;
    return [conversation.messages subarrayWithRange:NSMakeRange(start, count - start)];
}

#pragma mark - Search & Filtering

- (NSArray<AIConversation *> *)conversationsContainingText:(NSString *)searchText {
    if (!searchText || searchText.length == 0) return _conversations;

    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(AIConversation *conv, NSDictionary *bindings) {
        if ([conv.title localizedCaseInsensitiveContainsString:searchText]) return YES;
        for (AIMessage *msg in conv.messages) {
            if ([msg.content localizedCaseInsensitiveContainsString:searchText]) return YES;
        }
        return NO;
    }];
    return [_conversations filteredArrayUsingPredicate:predicate];
}

- (NSArray<AIConversation *> *)conversationsWithModel:(NSString *)model {
    if (!model) return _conversations;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"model == %@", model];
    return [_conversations filteredArrayUsingPredicate:predicate];
}

#pragma mark - Persistence

- (NSString *)conversationsFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[paths firstObject] stringByAppendingPathComponent:kConversationsFile];
}

- (void)saveAllConversations {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        NSMutableArray *array = [NSMutableArray array];
        for (AIConversation *conv in _conversations) {
            [array addObject:[conv dictionaryRepresentation]];
        }

        NSData *data = [NSJSONSerialization dataWithJSONObject:array options:NSJSONWritingPrettyPrinted error:nil];
        if (data) {
            [data writeToFile:[self conversationsFilePath] atomically:YES];
            _hasUnsavedChanges = NO;
        }
    });
}

- (void)loadAllConversations {
    NSString *path = [self conversationsFilePath];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return;

    NSError *error;
    NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) return;

    _conversations = [NSMutableArray array];
    for (NSDictionary *dict in array) {
        AIConversation *conv = [AIConversation conversationFromDictionary:dict];
        if (conv) [_conversations addObject:conv];
    }

    if (_conversations.count > 0) {
        _currentConversation = _conversations[0];
    }
}

- (BOOL)hasUnsavedChanges {
    return _hasUnsavedChanges;
}

#pragma mark - Export/Import

- (NSData *)exportConversation:(AIConversation *)conversation error:(NSError **)error {
    NSDictionary *dict = [conversation dictionaryRepresentation];
    return [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:error];
}

- (AIConversation *)importConversationFromData:(NSData *)data error:(NSError **)error {
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (error && *error) return nil;
    return [AIConversation conversationFromDictionary:dict];
}

#pragma mark - Settings

- (void)setDefaultModel:(NSString *)model { _defaultModel = model; }
- (NSString *)defaultModel { return _defaultModel ?: @"gpt-4o"; }
- (void)setDefaultSystemPrompt:(NSString *)prompt { _defaultSystemPrompt = prompt; }
- (NSString *)defaultSystemPrompt { return _defaultSystemPrompt; }
- (void)setDefaultTemperature:(float)temperature { _defaultTemperature = temperature; }
- (float)defaultTemperature { return _defaultTemperature ?: 0.7; }
- (void)setDefaultMaxTokens:(NSUInteger)maxTokens { _defaultMaxTokens = maxTokens; }
- (NSUInteger)defaultMaxTokens { return _defaultMaxTokens ?: 4096; }

@end

// Add dictionary representation to AIConversation
@implementation AIConversation (Serialization)

- (NSDictionary *)dictionaryRepresentation {
    NSMutableArray *messagesArray = [NSMutableArray array];
    for (AIMessage *msg in _messages) {
        [messagesArray addObject:[msg dictionaryRepresentation]];
    }

    return @{
        @"conversationID": _conversationID,
        @"title": _title,
        @"createdAt": _createdAt,
        @"updatedAt": _updatedAt,
        @"messages": messagesArray,
        @"systemPrompt": _systemPrompt,
        @"model": _model,
        @"temperature": @(_temperature),
        @"maxTokens": @(_maxTokens),
        @"metadata": _metadata,
    };
}

+ (instancetype)conversationFromDictionary:(NSDictionary *)dict {
    AIConversation *conv = [[self alloc] initWithID:dict[@"conversationID"]];
    conv.title = dict[@"title"] ?: @"Untitled";
    conv.createdAt = dict[@"createdAt"];
    conv.updatedAt = dict[@"updatedAt"];
    conv.systemPrompt = dict[@"systemPrompt"];
    conv.model = dict[@"model"];
    conv.temperature = [dict[@"temperature"] floatValue];
    conv.maxTokens = [dict[@"maxTokens"] unsignedIntegerValue];
    conv.metadata = dict[@"metadata"] ?: @{};

    NSMutableArray *messages = [NSMutableArray array];
    for (NSDictionary *msgDict in dict[@"messages"] ?: @[]) {
        AIMessage *msg = [AIMessage messageFromDictionary:msgDict];
        if (msg) [messages addObject:msg];
    }
    conv.messages = messages;

    return conv;
}

@end