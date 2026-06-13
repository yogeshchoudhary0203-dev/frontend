// local_db.dart
//
// SQLite-backed local persistence for Trandia.
// Provides offline cache for:
//   • Feed posts  (first page, shown instantly on app open)
//   • Conversations list (shown instantly on chat screen open)
//   • Messages     (last 50 per conversation, shown instantly)
//
// Pattern: stale-while-revalidate
//   1. Read local data → show immediately (zero network wait).
//   2. Fetch fresh from API in background → update UI silently.
//   3. Save fresh data to local DB for next open.

import 'dart:convert';
import 'dart:developer' as dev;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/chat_model.dart';
import 'post_service.dart';

const int _kDbVersion    = 1;
const String _kDbFile    = 'trandia_cache.db';
const int _kMaxFeedPosts = 30;    // first page of feed to keep offline
const int _kMaxMessages  = 50;    // messages per conversation to keep offline

// ─────────────────────────────────────────────────────────────────────────────
// Singleton
// ─────────────────────────────────────────────────────────────────────────────

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  // ── Open ─────────────────────────────────────────────────────────────────

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir  = await getDatabasesPath();
    final path = p.join(dir, _kDbFile);
    dev.log('[LocalDb] opening at $path');

    return openDatabase(
      path,
      version: _kDbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Feed posts — stores JSON blobs of PostModel
    await db.execute('''
      CREATE TABLE feed_posts (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL DEFAULT '',
        json_data   TEXT NOT NULL,
        saved_at    INTEGER NOT NULL
      )
    ''');

    // Conversations — one row per conversation
    await db.execute('''
      CREATE TABLE conversations (
        id          TEXT PRIMARY KEY,
        json_data   TEXT NOT NULL,
        saved_at    INTEGER NOT NULL
      )
    ''');

    // Messages — one row per message
    await db.execute('''
      CREATE TABLE messages (
        id              TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        json_data       TEXT NOT NULL,
        created_at_ms   INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_messages_conv ON messages(conversation_id, created_at_ms DESC)');

    dev.log('[LocalDb] schema created (v$version)');
  }

  // ── Close / clear ─────────────────────────────────────────────────────────

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Wipe all cached data (call on logout so next user starts fresh).
  Future<void> clearAll() async {
    final database = await db;
    await database.delete('feed_posts');
    await database.delete('conversations');
    await database.delete('messages');
    dev.log('[LocalDb] all tables cleared');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEED POSTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save/replace the first page of feed posts.
  /// Keeps at most [_kMaxFeedPosts] rows; older excess rows are dropped.
  Future<void> saveFeedPosts(List<PostModel> posts) async {
    if (posts.isEmpty) return;
    final database = await db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final batch = database.batch();
    for (final post in posts.take(_kMaxFeedPosts)) {
      batch.insert(
        'feed_posts',
        {
          'id':       post.id,
          'user_id':  post.userId,
          'json_data': jsonEncode(_postToJson(post)),
          'saved_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);

    // Enforce max — delete oldest beyond limit
    await database.execute('''
      DELETE FROM feed_posts
      WHERE id NOT IN (
        SELECT id FROM feed_posts ORDER BY saved_at DESC LIMIT $_kMaxFeedPosts
      )
    ''');
    dev.log('[LocalDb] saveFeedPosts: ${posts.length} rows');
  }

  /// Load cached feed posts, newest-saved first.
  Future<List<PostModel>> loadFeedPosts() async {
    final database = await db;
    final rows = await database.query(
      'feed_posts',
      orderBy: 'saved_at DESC',
      limit: _kMaxFeedPosts,
    );
    final posts = <PostModel>[];
    for (final row in rows) {
      try {
        final j = jsonDecode(row['json_data'] as String) as Map<String, dynamic>;
        posts.add(PostModel.fromJson(j));
      } catch (e) {
        dev.log('[LocalDb] loadFeedPosts parse error: $e');
      }
    }
    dev.log('[LocalDb] loadFeedPosts: ${posts.length} rows');
    return posts;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONVERSATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save/replace all conversations for the current user.
  Future<void> saveConversations(List<ChatConversation> conversations) async {
    if (conversations.isEmpty) return;
    final database = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = database.batch();
    for (final conv in conversations) {
      batch.insert(
        'conversations',
        {
          'id':        conv.id,
          'json_data': jsonEncode(_convToJson(conv)),
          'saved_at':  now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    dev.log('[LocalDb] saveConversations: ${conversations.length} rows');
  }

  /// Load all cached conversations, most-recently updated first.
  Future<List<ChatConversation>> loadConversations() async {
    final database = await db;
    final rows = await database.query(
      'conversations',
      orderBy: 'saved_at DESC',
    );
    final result = <ChatConversation>[];
    for (final row in rows) {
      try {
        final j = jsonDecode(row['json_data'] as String) as Map<String, dynamic>;
        result.add(ChatConversation.fromJson(j));
      } catch (e) {
        dev.log('[LocalDb] loadConversations parse error: $e');
      }
    }
    dev.log('[LocalDb] loadConversations: ${result.length} rows');
    return result;
  }

  /// Update a single conversation row (e.g. after receiving a new message).
  Future<void> upsertConversation(ChatConversation conv) async {
    final database = await db;
    await database.insert(
      'conversations',
      {
        'id':        conv.id,
        'json_data': jsonEncode(_convToJson(conv)),
        'saved_at':  DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save a batch of messages.  Oldest-beyond-limit are pruned automatically.
  Future<void> saveMessages(
    String conversationId,
    List<ChatMessage> messages,
  ) async {
    if (messages.isEmpty) return;
    final database = await db;
    final batch = database.batch();
    for (final msg in messages) {
      batch.insert(
        'messages',
        {
          'id':              msg.id,
          'conversation_id': conversationId,
          'json_data':       jsonEncode(_msgToJson(msg)),
          'created_at_ms':   msg.createdAt.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);

    // Keep only the latest _kMaxMessages per conversation
    await database.execute('''
      DELETE FROM messages
      WHERE conversation_id = ?
        AND id NOT IN (
          SELECT id FROM messages
          WHERE conversation_id = ?
          ORDER BY created_at_ms DESC
          LIMIT $_kMaxMessages
        )
    ''', [conversationId, conversationId]);

    dev.log('[LocalDb] saveMessages($conversationId): ${messages.length} rows');
  }

  /// Insert or update a single message (e.g. new WS message or reaction update).
  Future<void> upsertMessage(ChatMessage msg) async {
    final database = await db;
    await database.insert(
      'messages',
      {
        'id':              msg.id,
        'conversation_id': msg.conversationId,
        'json_data':       jsonEncode(_msgToJson(msg)),
        'created_at_ms':   msg.createdAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Load the latest messages for a conversation (newest-last for display).
  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    final database = await db;
    final rows = await database.query(
      'messages',
      where:   'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at_ms DESC',
      limit:   _kMaxMessages,
    );
    final result = <ChatMessage>[];
    for (final row in rows) {
      try {
        final j = jsonDecode(row['json_data'] as String) as Map<String, dynamic>;
        result.add(ChatMessage.fromJson(j));
      } catch (e) {
        dev.log('[LocalDb] loadMessages parse error: $e');
      }
    }
    // Reverse so oldest-first (normal chat display order)
    dev.log('[LocalDb] loadMessages($conversationId): ${result.length} rows');
    return result.reversed.toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SERIALIZATION HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _postToJson(PostModel p) => {
    'id':              p.id,
    'user_id':         p.userId,
    'user_name':       p.userName,
    'user_username':   p.userUsername,
    'user_picture':    p.userPicture,
    'media_url':       p.mediaUrl,
    'thumbnail_url':   p.thumbnailUrl,
    'public_id':       p.publicId,
    'media_type':      p.mediaType,
    'caption':         p.caption,
    'aspect_ratio':    p.aspectRatio,
    'section':         p.section,
    'learn_topic':     p.learnTopic,
    'likes_count':     p.likesCount,
    'comments_count':  p.commentsCount,
    'shares_count':    p.sharesCount,
    'is_liked':        p.isLiked,
    'created_at':      p.createdAt.toIso8601String(),
  };

  Map<String, dynamic> _convToJson(ChatConversation c) => {
    'id':                           c.id,
    'participants':                  c.participants.map((p) => p.toJson()).toList(),
    'last_message':                  c.lastMessage,
    'last_message_time':             c.lastMessageTime?.toUtc().toIso8601String(),
    'unread_counts':                 c.unreadCounts,
    'is_group':                      c.isGroup,
    'name':                          c.name,
    'last_message_encrypted_aes_keys': c.lastMessageEncryptedAesKeys,
  };

  Map<String, dynamic> _msgToJson(ChatMessage m) => {
    'id':               m.id,
    'conversation_id':  m.conversationId,
    'sender_id':        m.senderId,
    'text':             m.text,
    'created_at':       m.createdAt.toUtc().toIso8601String(),
    'read_by':          m.readBy,
    'encrypted_aes_keys': m.encryptedAesKeys,
    'reactions':        m.reactions.map((k, v) => MapEntry(k, v)),
    'reply_to_id':      m.replyToId,
    'reply_to_text':    m.replyToText,
    'media_url':        m.mediaUrl,
    'media_type':       m.mediaType,
    'media_public_id':  m.mediaPublicId,
    'is_view_once':     m.isViewOnce,
    'view_once_viewed_by': m.viewOnceViewedBy,
  };
}
