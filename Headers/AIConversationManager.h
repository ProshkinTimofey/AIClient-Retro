//
//  AIConversationManager.h
//  AIClient
//
//  Manages conversations, persistence, and message history.
//

#import <Foundation/Foundation.h>
#import "AIMessage.h"

@protocol AIConversationManagerDelegate <NSObject>

@optional
- (void)conversationManager:(id)manager didCreateConversation:(NSString *)conversationID;
- (void)conversationManager:(id)manager didUpdateConversation:(NSString *)conversationID;
- (void)conversationManager:(id)manager didDeleteConversation:(NSString *)conversationID;
- (void)conversationManager:(id)manager didAddMessage:(AIMessage *)message toConversation:(NSString *)conversationID;
- (void)conversationManager:(id)manager didUpdateMessage:(AIMessage *)message inConversation:(NSString *)conversationID;

@end

@interface AIConversation : NSObject <NSCopying, NSCoding>

@property (nonatomic, copy) NSString *conversationID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSDate *updatedAt;
@property (nonatomic, strong) NSArray<AIMessage *> *messages;
@property (nonatomic, copy) NSString *systemPrompt;
@property (nonatomic, copy) NSString *model;
@property (nonatomic, assign) float temperature;
@property (nonatomic, assign) NSUInteger maxTokens;
@property (nonatomic, copy) NSDictionary *metadata;

- (instancetype)initWithID:(NSString *)conversationID;
- (AIMessage *)lastMessage;
- (AIMessage *)lastUserMessage;
- (NSUInteger)messageCount;
- (NSUInteger)estimatedTokenCount;

@end

@interface AIConversationManager : NSObject

@property (nonatomic, weak) id<AIConversationManagerDelegate> delegate;
@property (nonatomic, readonly, strong) AIConversation *currentConversation;
@property (nonatomic, readonly, copy) NSArray<AIConversation *> *allConversations;

// Shared instance
+ (instancetype)sharedManager;

// Conversation lifecycle
- (AIConversation *)createNewConversationWithTitle:(NSString *)title;
- (AIConversation *)createNewConversationWithTitle:(NSString *)title systemPrompt:(NSString *)systemPrompt model:(NSString *)model;
- (void)switchToConversation:(AIConversation *)conversation;
- (void)deleteConversation:(AIConversation *)conversation completion:(void (^)(BOOL success, NSError *error))completion;
- (void)deleteConversationWithID:(NSString *)conversationID completion:(void (^)(BOOL success, NSError *error))completion;

// Message management
- (void)addMessage:(AIMessage *)message toConversation:(AIConversation *)conversation;
- (void)updateMessage:(AIMessage *)message inConversation:(AIConversation *)conversation;
- (void)removeMessage:(AIMessage *)message fromConversation:(AIConversation *)conversation;
- (NSArray<AIMessage *> *)messagesForConversation:(AIConversation *)conversation;
- (NSArray<AIMessage *> *)recentMessagesForConversation:(AIConversation *)conversation limit:(NSUInteger)limit;

// Search & filtering
- (NSArray<AIConversation *> *)conversationsContainingText:(NSString *)searchText;
- (NSArray<AIConversation *> *)conversationsWithModel:(NSString *)model;

// Persistence
- (void)saveAllConversations;
- (void)loadAllConversations;
- (BOOL)hasUnsavedChanges;

// Export/Import
- (NSData *)exportConversation:(AIConversation *)conversation error:(NSError **)error;
- (AIConversation *)importConversationFromData:(NSData *)data error:(NSError **)error;

// Settings
- (void)setDefaultModel:(NSString *)model;
- (NSString *)defaultModel;
- (void)setDefaultSystemPrompt:(NSString *)prompt;
- (NSString *)defaultSystemPrompt;
- (void)setDefaultTemperature:(float)temperature;
- (float)defaultTemperature;
- (void)setDefaultMaxTokens:(NSUInteger)maxTokens;
- (NSUInteger)defaultMaxTokens;

@end