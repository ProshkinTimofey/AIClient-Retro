//
//  AISQLiteManager.h
//  AIClient
//
//  SQLite-based storage for conversations, messages, and attachments.
//  Better performance than JSON for large datasets.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@class AIConversation;
@class AIMessage;
@class AIAttachment;

@interface AISQLiteManager : NSObject

+ (instancetype)sharedManager;

// Database lifecycle
- (BOOL)openDatabase:(NSError **)error;
- (void)closeDatabase;
- (BOOL)migrateIfNeeded:(NSError **)error;

// Conversations
- (BOOL)saveConversation:(AIConversation *)conversation error:(NSError **)error;
- (AIConversation *)loadConversationWithID:(NSString *)conversationID error:(NSError **)error;
- (NSArray<AIConversation *> *)loadAllConversationsWithError:(NSError **)error;
- (BOOL)deleteConversationWithID:(NSString *)conversationID error:(NSError **)error;
- (BOOL)updateConversationTitle:(NSString *)conversationID title:(NSString *)title error:(NSError **)error;

// Messages
- (BOOL)saveMessage:(AIMessage *)message forConversation:(NSString *)conversationID error:(NSError **)error;
- (BOOL)updateMessage:(AIMessage *)message forConversation:(NSString *)conversationID error:(NSError **)error;
- (NSArray<AIMessage *> *)loadMessagesForConversation:(NSString *)conversationID limit:(NSUInteger)limit offset:(NSUInteger)offset error:(NSError **)error;
- (BOOL)deleteMessage:(NSString *)messageID forConversation:(NSString *)conversationID error:(NSError **)error;

// Attachments
- (BOOL)saveAttachment:(AIAttachment *)attachment forMessage:(NSString *)messageID conversation:(NSString *)conversationID error:(NSError **)error;
- (NSArray<AIAttachment *> *)loadAttachmentsForMessage:(NSString *)messageID conversation:(NSString *)conversationID error:(NSError **)error;

// Search
- (NSArray<AIConversation *> *)searchConversations:(NSString *)query limit:(NSUInteger)limit error:(NSError **)error;

// Stats
- (NSUInteger)totalConversationCount;
- (NSUInteger)totalMessageCount;
- (unsigned long long)databaseSizeBytes;

// Maintenance
- (BOOL)vacuumDatabase:(NSError **)error;
- (BOOL)backupDatabaseToPath:(NSString *)path error:(NSError **)error;

@end