import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// On-device SQLite store for offline use:
///  - offline_mezmurs: downloaded Mezmurs (full JSON + local file paths + download state)
///  - sync_queue:      operations made offline, replayed through POST /sync
///  - reminders:       personal reminders (local-first, synced)
///  - favorites:       favorite ids (+ JSON) for offline access
///  - cache:           last good response of key screens (home, categories) for offline display
///  - directory:       staff phones only: members' QR ids, names, photos, member IDs and types, so
///                     QR scans and member searches work offline (attendance, borrowing)
class LocalDb {
  LocalDb._(this.db);
  final Database db;

  static Future<LocalDb> open({String? path}) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }
    final dbPath = path ?? (kIsWeb ? 'mezmur_zelideta.db' : p.join(await getDatabasesPath(), 'mezmur_zelideta.db'));
    final db = await openDatabase(
      dbPath,
      version: 6,
      onUpgrade: (db, from, _) async {
        if (from < 2) await db.execute('ALTER TABLE reminders ADD COLUMN borrowing_id INTEGER');
        if (from < 3) await _createDirectory(db);
        if (from < 4) {
          await db.execute('ALTER TABLE sync_queue ADD COLUMN user_id INTEGER');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_user ON sync_queue(user_id)');
        }
        if (from < 5) {
          await db.execute('ALTER TABLE cache ADD COLUMN is_sealed INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE cache ADD COLUMN perm_hash TEXT');
          await db.execute('ALTER TABLE cache ADD COLUMN required_perm TEXT');
        }
        if (from < 6) {
          await db.execute('CREATE TABLE IF NOT EXISTS book_favorites (book_id INTEGER, user_id INTEGER, json TEXT, PRIMARY KEY (book_id, user_id))');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_book_favorites_user ON book_favorites(user_id)');
        }
      },
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE offline_mezmurs (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            json TEXT NOT NULL,
            content_version INTEGER NOT NULL DEFAULT 1,
            with_audio INTEGER NOT NULL DEFAULT 0,
            audio_path TEXT,
            cover_path TEXT,
            size_bytes INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'queued',
            progress REAL NOT NULL DEFAULT 0,
            stale INTEGER NOT NULL DEFAULT 0,
            downloaded_at TEXT
          )''');
        await db.execute('CREATE INDEX idx_offline_title ON offline_mezmurs(title)');
        await db.execute('''
          CREATE TABLE sync_queue (
            op_id TEXT PRIMARY KEY,
            user_id INTEGER,
            type TEXT NOT NULL,
            payload TEXT NOT NULL,
            client_ts TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_user ON sync_queue(user_id)');
        await db.execute('''
          CREATE TABLE reminders (
            client_uuid TEXT PRIMARY KEY,
            server_id INTEGER,
            program_id INTEGER,
            borrowing_id INTEGER,
            title TEXT NOT NULL,
            note TEXT,
            remind_at TEXT NOT NULL,
            repeat TEXT NOT NULL DEFAULT 'none',
            is_enabled INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT,
            deleted INTEGER NOT NULL DEFAULT 0,
            notification_id INTEGER NOT NULL
          )''');
        await db.execute('CREATE TABLE favorites (mezmur_id INTEGER PRIMARY KEY, json TEXT)');
        await db.execute('CREATE TABLE IF NOT EXISTS book_favorites (book_id INTEGER, user_id INTEGER, json TEXT, PRIMARY KEY (book_id, user_id))');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_book_favorites_user ON book_favorites(user_id)');
        await db.execute('''
          CREATE TABLE cache (
            key TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_sealed INTEGER NOT NULL DEFAULT 0,
            perm_hash TEXT,
            required_perm TEXT
          )''');
        await _createDirectory(db);
      },
    );
    return LocalDb._(db);
  }

  static Future<void> _createDirectory(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS directory (
        id INTEGER PRIMARY KEY,
        uuid TEXT NOT NULL,
        full_name TEXT NOT NULL,
        member_id TEXT,
        member_group TEXT,
        json TEXT NOT NULL
      )''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_directory_uuid ON directory(uuid)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_directory_name ON directory(full_name)');
  }

  // ---- generic JSON cache -------------------------------------------------
  Future<void> putCache(
    String key,
    Object json, {
    bool isSealed = false,
    String? permHash,
    String? requiredPerm,
  }) =>
      db.insert(
        'cache',
        {
          'key': key,
          'json': json is String ? json : jsonEncode(json),
          'updated_at': DateTime.now().toIso8601String(),
          'is_sealed': isSealed ? 1 : 0,
          'perm_hash': permHash,
          'required_perm': requiredPerm,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<Map<String, Object?>?> getCacheRow(String key) async {
    final rows = await db.query('cache', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<dynamic> getCache(String key) async {
    final rows = await db.query('cache', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : jsonDecode(rows.first['json'] as String);
  }

  /// Drop old offline copies of API responses (kept 45 days).
  Future<void> pruneHttpCache() => db.delete(
        'cache',
        where: "key LIKE 'http:%' AND updated_at < ?",
        whereArgs: [DateTime.now().subtract(const Duration(days: 45)).toIso8601String()],
      );

  /// Wipe everything that belongs to the signed-in user (on logout).
  /// If [discardUserId] is provided, deletes that user's queued operations; otherwise preserves them.
  Future<void> clearUserData({int? discardUserId}) async {
    if (discardUserId != null) {
      await db.delete('sync_queue', where: 'user_id = ?', whereArgs: [discardUserId]);
    }
    await pruneStaleSyncQueue();
    await db.delete('reminders');
    await db.delete('favorites');
    await db.delete('cache');
    await db.delete('directory');
  }

  /// Drop sync queue items older than 30 days.
  Future<void> pruneStaleSyncQueue() => db.delete(
        'sync_queue',
        where: 'client_ts < ?',
        whereArgs: [DateTime.now().toUtc().subtract(const Duration(days: 30)).toIso8601String()],
      );
}
