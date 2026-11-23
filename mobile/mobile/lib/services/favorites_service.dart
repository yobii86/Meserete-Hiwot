import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/providers.dart';
import '../features/auth/session.dart' show currentUserProvider;
import '../models/content.dart';
import '../models/json.dart';
import '../repositories/providers.dart';
import 'sync_service.dart';

/// Favorite Mezmur ids, available offline. Writes are optimistic and go through the sync queue.
class FavoritesController extends Notifier<Set<int>> {
  late Future<void> _ready;

  @override
  Set<int> build() {
    _ready = _load();
    return const {};
  }

  Future<void> _load() async {
    final rows = await ref.read(localDbProvider).db.query('favorites', columns: ['mezmur_id']);
    state = rows.map((r) => r['mezmur_id'] as int).toSet();
  }

  bool isFavorite(int id) => state.contains(id);

  Future<bool> toggle(MezmurSummary m) async {
    await _ready; // never let the initial load overwrite a user action
    final db = ref.read(localDbProvider).db;
    final sync = ref.read(syncServiceProvider);
    if (state.contains(m.id)) {
      state = {...state}..remove(m.id);
      await db.delete('favorites', where: 'mezmur_id = ?', whereArgs: [m.id]);
      await sync.enqueue(SyncOp.favoriteRemove, {'mezmur_id': m.id});
      return false;
    }
    state = {...state, m.id};
    await db.insert('favorites', {'mezmur_id': m.id, 'json': jsonEncode(_summaryJson(m))}, conflictAlgorithm: ConflictAlgorithm.replace);
    await sync.enqueue(SyncOp.favoriteAdd, {'mezmur_id': m.id});
    return true;
  }

  /// Offline list of favorites (summaries captured when favorited / last pulled).
  Future<List<MezmurSummary>> offlineList() async {
    final rows = await ref.read(localDbProvider).db.query('favorites');
    return rows.where((r) => r['json'] != null).map((r) => MezmurSummary.fromJson(asJson(jsonDecode(r['json'] as String)))).toList();
  }

  /// Replace local state with the server's list (only when no favorite ops are pending).
  Future<void> pull() async {
    await _ready;
    final db = ref.read(localDbProvider).db;
    final pending = await db.query('sync_queue', where: 'type LIKE ?', whereArgs: ['favorite.%'], limit: 1);
    if (pending.isNotEmpty) return;
    final api = ref.read(apiClientProvider);
    final page = await api.getPage('/favorites', MezmurSummary.fromJson, limit: 100);
    final batch = db.batch()..delete('favorites');
    for (final m in page.items) {
      batch.insert('favorites', {'mezmur_id': m.id, 'json': jsonEncode(_summaryJson(m))});
    }
    await batch.commit(noResult: true);
    state = page.items.map((m) => m.id).toSet();
    if (page.hasMore) {
      final ids = await api.get<List<dynamic>>('/favorites', query: {'ids_only': 'true'});
      state = ids.map((e) => asIntOr(e)).toSet();
    }
  }

  static Json _summaryJson(MezmurSummary m) => {
        'id': m.id,
        'title': m.title,
        'excerpt': m.excerpt,
        'category': m.categoryId == null ? null : {'id': m.categoryId, 'name': m.categoryName},
        'cover_url': m.coverUrl,
        'has_audio': m.hasAudio,
        'audio_duration_sec': m.audioDurationSec,
        'is_favorite': true,
      };
}

final favoritesProvider = NotifierProvider<FavoritesController, Set<int>>(FavoritesController.new);

/// Favorite Book IDs across the Education library, reactive and persisted with user isolation.
class BookFavoritesController extends Notifier<Set<int>> {
  late Future<void> _ready;
  bool _isInitialized = false;
  int _userId = 0;

  @override
  Set<int> build() {
    final user = ref.watch(currentUserProvider);
    _userId = user?.id ?? 0;
    if (_userId > 0) {
      _ready = _load(_userId).then((_) => pull());
    } else {
      _ready = Future.value();
    }
    return const {};
  }

  Future<void> _ensureTable(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS book_favorites (book_id INTEGER, user_id INTEGER, json TEXT, PRIMARY KEY (book_id, user_id))');
  }

  Future<void> _load(int userId) async {
    try {
      final db = ref.read(localDbProvider).db;
      await _ensureTable(db);
      final rows = await db.query(
        'book_favorites',
        columns: ['book_id'],
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      if (_userId == userId) {
        state = rows.map((r) => r['book_id'] as int).toSet();
      }
    } catch (_) {}
  }

  /// Pull latest favorites from server and sync to SQLite
  Future<void> pull() async {
    final uid = _userId;
    if (uid <= 0) return;
    try {
      final ids = await ref.read(libraryRepositoryProvider).getFavoriteBookIds();
      if (_userId != uid) return; // user switched during pull
      state = ids.toSet();
      _isInitialized = true;

      final db = ref.read(localDbProvider).db;
      await _ensureTable(db);
      final batch = db.batch();
      batch.delete('book_favorites', where: 'user_id = ?', whereArgs: [uid]);
      for (final id in ids) {
        batch.insert(
          'book_favorites',
          {
            'book_id': id,
            'user_id': uid,
            'json': jsonEncode({'id': id, 'is_favorite': true}),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  bool isFavorite(int id, [bool? fallback]) {
    if (state.contains(id)) return true;
    if (_isInitialized) return false;
    return fallback ?? false;
  }

  void mark(int id, bool fav) {
    if (fav) {
      state = {...state, id};
    } else {
      state = {...state}..remove(id);
    }
  }

  Future<bool> toggle(int bookId, {bool? currentState}) async {
    await _ready;
    final uid = _userId;
    if (uid <= 0) return false;

    final cur = currentState ?? isFavorite(bookId);
    final next = !cur;
    mark(bookId, next);

    final db = ref.read(localDbProvider).db;
    try {
      await _ensureTable(db);
      if (next) {
        await db.insert(
          'book_favorites',
          {
            'book_id': bookId,
            'user_id': uid,
            'json': jsonEncode({'id': bookId, 'is_favorite': true}),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await db.delete(
          'book_favorites',
          where: 'book_id = ? AND user_id = ?',
          whereArgs: [bookId, uid],
        );
      }
    } catch (_) {}

    try {
      final res = await ref.read(libraryRepositoryProvider).toggleFavorite(bookId, currentState: cur);
      if (res != next) {
        mark(bookId, res);
        try {
          if (res) {
            await db.insert(
              'book_favorites',
              {
                'book_id': bookId,
                'user_id': uid,
                'json': jsonEncode({'id': bookId, 'is_favorite': true}),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } else {
            await db.delete(
              'book_favorites',
              where: 'book_id = ? AND user_id = ?',
              whereArgs: [bookId, uid],
            );
          }
        } catch (_) {}
      }
      return res;
    } catch (e) {
      // Rollback on failure
      mark(bookId, cur);
      try {
        if (cur) {
          await db.insert(
            'book_favorites',
            {
              'book_id': bookId,
              'user_id': uid,
              'json': jsonEncode({'id': bookId, 'is_favorite': true}),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          await db.delete(
            'book_favorites',
            where: 'book_id = ? AND user_id = ?',
            whereArgs: [bookId, uid],
          );
        }
      } catch (_) {}
      return cur;
    }
  }
}

final bookFavoritesProvider = NotifierProvider<BookFavoritesController, Set<int>>(BookFavoritesController.new);

