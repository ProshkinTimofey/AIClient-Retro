//
//  AISQLiteManager.m
//  AIClient
//

#import "AISQLiteManager.h"
#import "AIConversation.h"
#import "AIMessage.h"
#import "AIAttachment.h"

static AISQLiteManager *_sharedManager = nil;
static const int kCurrentSchemaVersion = 3;

@implementation AISQLiteManager

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
        _db = NULL;
        _dbPath = nil;
    }
    return self;
}

#pragma mark - Database Lifecycle

- (BOOL)openDatabase:(NSError **)error {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    _dbPath = [[paths firstObject] stringByAppendingPathComponent:@"aiclient.db"];

    int rc = sqlite3_open_v2([_dbPath UTF8String], &_db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, NULL);
    if (rc != SQLITE_OK) {
        if (error) *error = [NSError errorWithDomain:@"AISQLiteManager" code:rc userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:sqlite3_errmsg(_db)]}];
        return NO;
    }

    // Enable WAL mode for better concurrency
    sqlite3_exec(_db, "PRAGMA journal_mode=WAL;", NULL, NULL, NULL);
    sqlite3_exec(_db, "PRAGMA foreign_keys=ON;", NULL, NULL, NULL);
    sqlite3_exec(_db, "PRAGMA busy_timeout=5000;", NULL, NULL, NULL);

    return [self migrateIfNeeded:error];
}

- (void)closeDatabase {
    if (_db) {
        sqlite3_close(_db);
        _db = NULL;
    }
}

- (BOOL)migrateIfNeeded:(NSError **)error {
    // Create schema version table
    const char *createVersionTable = "CREATE TABLE IF NOT EXISTS schema_version (version INTEGER PRIMARY KEY);";
    sqlite3_exec(_db, createVersionTable, NULL, NULL, NULL);

    // Get current version
    int currentVersion = 0;
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, "SELECT version FROM schema_version LIMIT 1;", -1, &stmt, NULL) == SQLITE_OK) {
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            currentVersion = sqlite3_column_int(stmt, 0);
        }
        sqlite3_finalize(stmt);
    }

    if (currentVersion >= kCurrentSchemaVersion) return YES;

    // Run migrations
    for (int v = currentVersion + 1; v <= kCurrentSchemaVersion; v++) {
        if (![self migrateToVersion:v error:error]) {
            return NO;
        }
    }

    // Update version
    char *updateVersion = sqlite3_mprintf("INSERT OR REPLACE INTO schema_version (version) VALUES (%d);", kCurrentSchemaVersion);
    sqlite3_exec(_db, updateVersion, NULL, NULL, NULL);
    sqlite3_free(updateVersion);

    return YES;
}

- (BOOL)migrateToVersion:(int)version error:(NSError **)error {
    const char *sql = NULL;

    switch (version) {
        case 1: {
            // Initial schema
            sql = "CREATE TABLE conversations ("
                  "conversation_id TEXT PRIMARY KEY,"
                  "title TEXT NOT NULL,"
                  "system_prompt TEXT,"
                  "model TEXT,"
                  "temperature REAL DEFAULT 0.7,"
                  "max_tokens INTEGER DEFAULT 4096,"
                  "created_at REAL NOT NULL,"
                  "updated_at REAL NOT NULL,"
                  "metadata TEXT"
                  ");"
                  "CREATE TABLE messages ("
                  "message_id TEXT PRIMARY KEY,"
                  "conversation_id TEXT NOT NULL,"
                  "role INTEGER NOT NULL,"
                  "content TEXT,"
                  "status INTEGER DEFAULT 0,"
                  "model TEXT,"
                  "token_count INTEGER DEFAULT 0,"
                  "tool_call_id TEXT,"
                  "tool_name TEXT,"
                  "tool_arguments TEXT,"
                  "tool_result TEXT,"
                  "metadata TEXT,"
                  "error_message TEXT,"
                  "timestamp REAL NOT NULL,"
                  "FOREIGN KEY(conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE"
                  ");"
                  "CREATE TABLE attachments ("
                  "attachment_id TEXT PRIMARY KEY,"
                  "message_id TEXT NOT NULL,"
                  "conversation_id TEXT NOT NULL,"
                  "type INTEGER NOT NULL,"
                  "source INTEGER NOT NULL,"
                  "file_name TEXT,"
                  "mime_type TEXT,"
                  "file_size INTEGER DEFAULT 0,"
                  "uti_type TEXT,"
                  "local_path TEXT,"
                  "remote_url TEXT,"
                  "base64_data TEXT,"
                  "provider_file_id TEXT,"
                  "provider_type TEXT,"
                  "pixel_width REAL DEFAULT 0,"
                  "pixel_height REAL DEFAULT 0,"
                  "is_uploaded INTEGER DEFAULT 0,"
                  "FOREIGN KEY(message_id) REFERENCES messages(message_id) ON DELETE CASCADE,"
                  "FOREIGN KEY(conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE"
                  ");"
                  "CREATE INDEX idx_messages_conversation ON messages(conversation_id, timestamp);"
                  "CREATE INDEX idx_attachments_message ON attachments(message_id);";
            break;
        }
        case 2: {
            // Add full-text search
            sql = "CREATE VIRTUAL TABLE conversations_fts USING fts5(title, content, content=conversations, content_rowid=rowid);"
                  "CREATE TRIGGER conversations_ai AFTER INSERT ON conversations BEGIN "
                  "INSERT INTO conversations_fts(rowid, title, content) VALUES (new.rowid, new.title, ''); END;"
                  "CREATE TRIGGER conversations_ad AFTER DELETE ON conversations BEGIN "
                  "INSERT INTO conversations_fts(conversations_fts, rowid, title, content) VALUES ('delete', old.rowid, old.title, ''); END;"
                  "CREATE TRIGGER conversations_au AFTER UPDATE ON conversations BEGIN "
                  "INSERT INTO conversations_fts(conversations_fts, rowid, title, content) VALUES ('delete', old.rowid, old.title, ''); "
                  "INSERT INTO conversations_fts(rowid, title, content) VALUES (new.rowid, new.title, ''); END;";
            break;
        }
        case 3: {
            // Add message content to FTS
            sql = "CREATE VIRTUAL TABLE messages_fts USING fts5(content, content=messages, content_rowid=rowid);"
                  "CREATE TRIGGER messages_ai AFTER INSERT ON messages BEGIN "
                  "INSERT INTO messages_fts(rowid, content) VALUES (new.rowid, new.content); END;"
                  "CREATE TRIGGER messages_ad AFTER DELETE ON messages BEGIN "
                  "INSERT INTO messages_fts(messages_fts, rowid, content) VALUES ('delete', old.rowid, old.content); END;"
                  "CREATE TRIGGER messages_au AFTER UPDATE ON messages BEGIN "
                  "INSERT INTO messages_fts(messages_fts, rowid, content) VALUES ('delete', old.rowid, old.content); "
                  "INSERT INTO messages_fts(rowid, content) VALUES (new.rowid, new.content); END;";
            break;
        }
    }

    if (sql) {
        char *errMsg = NULL;
        int rc = sqlite3_exec(_db, sql, NULL, NULL, &errMsg);
        if (rc != SQLITE_OK) {
            if (error) *error = [NSError errorWithDomain:@"AISQLiteManager" code:rc userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:errMsg]}];
            sqlite3_free(errMsg);
            return NO;
        }
    }

    return YES;
}

#pragma mark - Conversations

- (BOOL)saveConversation:(AIConversation *)conversation error:(NSError **)error {
    const char *sql = "INSERT OR REPLACE INTO conversations "
                      "(conversation_id, title, system_prompt, model, temperature, max_tokens, created_at, updated_at, metadata) "
                      "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);";

    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) {
        if (error) *error = [self lastError];
        return NO;
    }

    sqlite3_bind_text(stmt, 1, [conversation.conversationID UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, [conversation.title UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 3, [conversation.systemPrompt UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 4, [conversation.model UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_double(stmt, 5, conversation.temperature);
    sqlite3_bind_int64(stmt, 6, conversation.maxTokens);
    sqlite3_bind_double(stmt, 7, [conversation.createdAt timeIntervalSince1970]);
    sqlite3_bind_double(stmt, 8, [conversation.updatedAt timeIntervalSince1970]);
    sqlite3_bind_text(stmt, 9, [[conversation.metadata JSONString] UTF8String], -1, SQLITE_TRANSIENT);

    BOOL success = sqlite3_step(stmt) == SQLITE_DONE;
    sqlite3_finalize(stmt);

    if (!success && error) *error = [self lastError];
    return success;
}

- (AIConversation *)loadConversationWithID:(NSString *)conversationID error:(NSError **)error {
    const char *sql = "SELECT * FROM conversations WHERE conversation_id = ?;";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) {
        if (error) *error = [self lastError];
        return nil;
    }

    sqlite3_bind_text(stmt, 1, [conversationID UTF8String], -1, SQLITE_TRANSIENT);

    AIConversation *conversation = nil;
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        conversation = [self conversationFromStatement:stmt];
    }
    sqlite3_finalize(stmt);

    if (conversation) {
        conversation.messages = [self loadMessagesForConversation:conversationID limit:0 offset:0 error:nil];
    }
    return conversation;
}

- (NSArray<AIConversation *> *)loadAllConversationsWithError:(NSError **)error {
    const char *sql = "SELECT * FROM conversations ORDER BY updated_at DESC;";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) {
        if (error) *error = [self lastError];
        return @[];
    }

    NSMutableArray *conversations = [NSMutableArray array];
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        AIConversation *conv = [self conversationFromStatement:stmt];
        if (conv) [conversations addObject:conv];
    }
    sqlite3_finalize(stmt);
    return conversations;
}

- (BOOL)deleteConversationWithID:(NSString *)conversationID error:(NSError **)error {
    const char *sql = "DELETE FROM conversations WHERE conversation_id = ?;";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) {
        if (error) *error = [self lastError];
        return NO;
    }

    sqlite3_bind_text(stmt, 1, [conversationID UTF8String], -1, SQLITE_TRANSIENT);
    BOOL success = sqlite3_step(stmt) == SQLITE_DONE;
    sqlite3_finalize(stmt);

    if (!success && error) *error = [self lastError];
    return success;
}

- (BOOL)updateConversationTitle:(NSString *)conversationID title:(NSString *)title error:(NSError **)error {
    const char *sql = "UPDATE conversations SET title = ?, updated_at = ? WHERE conversation_id = ?;";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) {
        if (error) *error = [self lastError];
        return NO;
    }

    sqlite3_bind_text(stmt, 1, [title UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_double(stmt, 2, [[NSDate date] timeIntervalSince1970]);
    sqlite3_bind_text(stmt, 3, [conversationID UTF8String], -1, SQLITE_TRANSIENT);

    BOOL success = sqlite3_step(stmt) == SQLITE_DONE;
    sqlite3_finalize(stmt);

    if (!success && error) *error = [self lastError];
    return success;
}

#pragma mark - Messages

- (BOOL)saveMessage:(AIMessage *)message forConversation:(NSString *)conversationID error:(NSError **)error {
    const char *sql = "INSERT OR REPLACE INTO messages "
                      "(message_id, conversation_id, role, content, status, model, token_count, tool_call_id, tool_name, tool_arguments, tool_result, metadata, error_message, timestamp) "
                      "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);";

    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) {
        if (error) *error = [self lastError];
        return NO;
    }

    sqlite3_bind_text(stmt, 1, [message.messageID UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, [conversationID UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_int(stmt, 3, message.role);
    sqlite3_bind_text(stmt, 4, [message.content UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_int(stmt, 5, message.status);
    sqlite3_bind_text(stmt, 6, [message.model UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(stmt, 7, message.tokenCount);
    sqlite3_bind_text(stmt, 8, [message.toolCallID UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 9, [message.toolName UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 10, [[message.toolArguments JSONString] UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 11, [message.toolResult UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 12, [[message.metadata JSONString] UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 13, [message.errorMessage UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_double(stmt, 14, [message.timestamp timeIntervalSince1970]);

    BOOL success = sqlite3_step(stmt) == SQLITE_DONE;
    sqlite3_finalize(stmt);

    // Save attachments
    if (success) {
        for (AIAttachment *att in message.attachments) {
            [self saveAttachment:att forMessage:message.messageID conversation:conversationID error:nil];
        }
    }

    if (!success && error) *error = [self lastError];
    return success;
}

- (BOOL)updateMessage:(AIMessage *)message forConversation:(NSString *)conversationID error:(NSError **)error {
    return [self saveMessage:message forConversation:conversationID error:error]; // Same as upsert
}

- (NSArray<AIMessage *> *)loadMessagesForConversation:(NSString *)conversationID limit:(NSUInteger)limit offset:(NSUInteger)offset error:(NSError **)error {
    NSString *sql = @"SELECT * FROM messages WHERE conversation_id = ? ORDER BY timestamp ASC";
    if (limit > 0) {
        sql = [sql stringByAppendingFormat:@" LIMIT %lu OFFSET %lu", (unsigned long)limit, (unsigned long)offset];
    }

    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, [sql UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
        if (error) *error = [self lastError];
        return @[];
    }

    sqlite3_bind_text(stmt, 1, [conversationID UTF8String], -1, SQLITE_TRANSIENT);

    NSMutableArray *messages = [NSMutableArray array];
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        AIMessage *msg = [self messageFromStatement:stmt];
        if (msg) {
            msg.attachments = [self loadAttachmentsForMessage:msg.messageID conversation:conversationID error:nil];
            [messages addObject:msg];
        }
    }
    sqlite3_finalize(stmt);
    return messages;
}

- (BOOL)deleteMessage:(NSString *)messageID forConversation:(NSString *)conversationID error:(NSError **)error {
    const char *sql = "DELETE FROM messages WHERE message_id = ? AND conversation_id = ?;";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) {
        if (error) *error = [self lastError];
        return NO;
    }

    sqlite3_bind_text(stmt, 1, [messageID UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, [conversationID UTF8String], -1, SQLITE_TRANSIENT);

    BOOL success = sqlite3_step(stmt) == SQLITE_DONE;
    sqlite3_finalize(stmt);

    if (!success && error) *error = [self lastError];
    return success;
}

#pragma mark - Attachments

- (BOOL)saveAttachment:(AIAttachment *)attachment forMessage:(NSString *)messageID conversation:(NSString *)conversationID error:(NSError **)error {
    const char *sql = "INSERT OR REPLACE INTO attachments "
                      "(attachment_id, message_id, conversation_id, type, source, file_name, mime_type, file_size, uti_type, local_path, remote_url, base64_data, provider_file_id, provider_type, pixel_width, pixel_height, is_uploaded) "
                      "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);";

    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) {
        if (error) *error = [self lastError];
        return NO;
    }

    sqlite3_bind_text(stmt, 1, [attachment.attachmentID UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, [messageID UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 3, [conversationID UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_int(stmt, 4, attachment.type);
    sqlite3_bind_int(stmt, 5, attachment.source);
    sqlite3_bind_text(stmt, 6, [attachment.fileName UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 7, [attachment.mimeType UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(stmt, 8, attachment.fileSize);
    sqlite3_bind_text(stmt, 9, [attachment.utiType UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 10, [attachment.localPath UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 11, [attachment.remoteURL UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 12, [attachment.base64Data UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 13, [attachment.providerFileID UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 14, [attachment.providerType UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_double(stmt, 15, attachment.pixelSize.width);
    sqlite3_bind_double(stmt, 16, attachment.pixelSize.height);
    sqlite3_bind_int(stmt, 17, attachment.isUploaded);

    BOOL success = sqlite3_step(stmt) == SQLITE_DONE;
    sqlite3_finalize(stmt);

    if (!success && error) *error = [self lastError];
    return success;
}

- (NSArray<AIAttachment *> *)loadAttachmentsForMessage:(NSString *)messageID conversation:(NSString *)conversationID error:(NSError **)error {
    const char *sql = "SELECT * FROM attachments WHERE message_id = ? AND conversation_id = ?;";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) {
        if (error) *error = [self lastError];
        return @[];
    }

    sqlite3_bind_text(stmt, 1, [messageID UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, [conversationID UTF8String], -1, SQLITE_TRANSIENT);

    NSMutableArray *attachments = [NSMutableArray array];
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        AIAttachment *att = [self attachmentFromStatement:stmt];
        if (att) [attachments addObject:att];
    }
    sqlite3_finalize(stmt);
    return attachments;
}

#pragma mark - Search

- (NSArray<AIConversation *> *)searchConversations:(NSString *)query limit:(NSUInteger)limit error:(NSError **)error {
    NSString *sql = [NSString stringWithFormat:@"SELECT c.* FROM conversations c JOIN conversations_fts f ON c.rowid = f.rowid WHERE conversations_fts MATCH ? ORDER BY c.updated_at DESC LIMIT %lu;", (unsigned long)limit];
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, [sql UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
        if (error) *error = [self lastError];
        return @[];
    }

    sqlite3_bind_text(stmt, 1, [query UTF8String], -1, SQLITE_TRANSIENT);

    NSMutableArray *conversations = [NSMutableArray array];
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        AIConversation *conv = [self conversationFromStatement:stmt];
        if (conv) [conversations addObject:conv];
    }
    sqlite3_finalize(stmt);
    return conversations;
}

#pragma mark - Stats

- (NSUInteger)totalConversationCount {
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, "SELECT COUNT(*) FROM conversations;", -1, &stmt, NULL) == SQLITE_OK) {
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            NSUInteger count = sqlite3_column_int(stmt, 0);
            sqlite3_finalize(stmt);
            return count;
        }
        sqlite3_finalize(stmt);
    }
    return 0;
}

- (NSUInteger)totalMessageCount {
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, "SELECT COUNT(*) FROM messages;", -1, &stmt, NULL) == SQLITE_OK) {
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            NSUInteger count = sqlite3_column_int(stmt, 0);
            sqlite3_finalize(stmt);
            return count;
        }
        sqlite3_finalize(stmt);
    }
    return 0;
}

- (unsigned long long)databaseSizeBytes {
    struct stat st;
    if (stat([_dbPath UTF8String], &st) == 0) {
        return st.st_size;
    }
    return 0;
}

#pragma mark - Maintenance

- (BOOL)vacuumDatabase:(NSError **)error {
    char *errMsg = NULL;
    int rc = sqlite3_exec(_db, "VACUUM;", NULL, NULL, &errMsg);
    if (rc != SQLITE_OK) {
        if (error) *error = [NSError errorWithDomain:@"AISQLiteManager" code:rc userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:errMsg]}];
        sqlite3_free(errMsg);
        return NO;
    }
    return YES;
}

- (BOOL)backupDatabaseToPath:(NSString *)path error:(NSError **)error {
    sqlite3 *destDb;
    int rc = sqlite3_open_v2([path UTF8String], &destDb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL);
    if (rc != SQLITE_OK) {
        if (error) *error = [NSError errorWithDomain:@"AISQLiteManager" code:rc userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:sqlite3_errmsg(destDb)]}];
        return NO;
    }

    sqlite3_backup *backup = sqlite3_backup_init(destDb, "main", _db, "main");
    if (!backup) {
        if (error) *error = [NSError errorWithDomain:@"AISQLiteManager" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to init backup"}];
        sqlite3_close(destDb);
        return NO;
    }

    rc = sqlite3_backup_step(backup, -1);
    sqlite3_backup_finish(backup);
    sqlite3_close(destDb);

    if (rc != SQLITE_DONE) {
        if (error) *error = [NSError errorWithDomain:@"AISQLiteManager" code:rc userInfo:@{NSLocalizedDescriptionKey: @"Backup failed"}];
        return NO;
    }
    return YES;
}

#pragma mark - Helpers

- (AIConversation *)conversationFromStatement:(sqlite3_stmt *)stmt {
    AIConversation *conv = [[AIConversation alloc] initWithID:[NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 0)]];
    conv.title = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 1)];
    conv.systemPrompt = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 2)];
    conv.model = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 3)];
    conv.temperature = sqlite3_column_double(stmt, 4);
    conv.maxTokens = sqlite3_column_int64(stmt, 5);
    conv.createdAt = [NSDate dateWithTimeIntervalSince1970:sqlite3_column_double(stmt, 6)];
    conv.updatedAt = [NSDate dateWithTimeIntervalSince1970:sqlite3_column_double(stmt, 7)];

    const unsigned char *metadata = sqlite3_column_text(stmt, 8);
    if (metadata) {
        conv.metadata = [[NSString stringWithUTF8String:(const char *)metadata] JSONDictionary];
    }
    return conv;
}

- (AIMessage *)messageFromStatement:(sqlite3_stmt *)stmt {
    AIMessage *msg = [[AIMessage alloc] init];
    msg.messageID = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 0)];
    msg.role = sqlite3_column_int(stmt, 2);
    msg.content = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 3)];
    msg.status = sqlite3_column_int(stmt, 4);
    msg.model = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 5)];
    msg.tokenCount = sqlite3_column_int64(stmt, 6);
    msg.toolCallID = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 7)];
    msg.toolName = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 8)];

    const unsigned char *toolArgs = sqlite3_column_text(stmt, 9);
    if (toolArgs) msg.toolArguments = [[NSString stringWithUTF8String:(const char *)toolArgs] JSONDictionary];

    msg.toolResult = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 10)];

    const unsigned char *metadata = sqlite3_column_text(stmt, 11);
    if (metadata) msg.metadata = [[NSString stringWithUTF8String:(const char *)metadata] JSONDictionary];

    msg.errorMessage = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 12)];
    msg.timestamp = [NSDate dateWithTimeIntervalSince1970:sqlite3_column_double(stmt, 13)];
    return msg;
}

- (AIAttachment *)attachmentFromStatement:(sqlite3_stmt *)stmt {
    AIAttachment *att = [[AIAttachment alloc] init];
    att.attachmentID = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 0)];
    att.type = sqlite3_column_int(stmt, 3);
    att.source = sqlite3_column_int(stmt, 4);
    att.fileName = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 5)];
    att.mimeType = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 6)];
    att.fileSize = sqlite3_column_int64(stmt, 7);
    att.utiType = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 8)];
    att.localPath = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 9)];
    att.remoteURL = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 10)];
    att.base64Data = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 11)];
    att.providerFileID = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 12)];
    att.providerType = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 13)];
    att.pixelSize = CGSizeMake(sqlite3_column_double(stmt, 14), sqlite3_column_double(stmt, 15));
    att.isUploaded = sqlite3_column_int(stmt, 16);
    return att;
}

- (NSError *)lastError {
    return [NSError errorWithDomain:@"AISQLiteManager" code:sqlite3_errcode(_db) userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:sqlite3_errmsg(_db)]}];
}

@end

// Helper category for JSON
@implementation NSString (JSON)

- (NSDictionary *)JSONDictionary {
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}

- (NSString *)JSONString {
    return self;
}

@end

@implementation NSDictionary (JSON)

- (NSString *)JSONString {
    NSData *data = [NSJSONSerialization dataWithJSONObject:self options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end

@implementation NSArray (JSON)

- (NSString *)JSONString {
    NSData *data = [NSJSONSerialization dataWithJSONObject:self options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end