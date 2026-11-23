import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/network/api_client.dart';
import '../core/providers.dart';
import '../features/auth/session.dart';
import '../models/json.dart';
import 'book_vault.dart';
import 'sync_status.dart';

/// Operation types understood by POST /sync.
abstract final class SyncOp {
  static const favoriteAdd = 'favorite.add';
  static const favoriteRemove = 'favorite.remove';
  static const downloadAdd = 'download.add';
  static const downloadRemove = 'download.remove';
  static const reminderCreate = 'reminder.create';
  static const reminderUpdate = 'reminder.update';
  static const reminderDelete = 'reminder.delete';
  static const activity = 'activity';
  static const preferencesUpdate = 'preferences.update';
  // Staff work that keeps going offline. Attendance: the assigned taker starts / ends the
  // occurrence's session and records each member (signed); times are the phone's capture times.
  static const attendanceSessionStart = 'attendance.session.start';
  static const attendanceSessionEnd = 'attendance.session.end';
  static const attendanceRecord = 'attendance.record';

  /// Queued by earlier app versions (still read from the queue and accepted by the server).
  static const attendanceSet = 'attendance.set';
  static const attendanceClear = 'attendance.clear';
  static const attendanceBulk = 'attendance.bulk';
  static const eduAttendanceSet = 'edu_attendance.set';
  static const eduAttendanceScan = 'edu_attendance.scan';
  static const borrowingCreate = 'borrowing.create';
  static const borrowingReturn = 'borrowing.return';
  // Project Management: a task's status / progress changed while offline.
  static const projectTaskUpdate = 'project.task.update';
  // Library circulation & education lessons (D9)
  static const libraryCheckout = 'library.checkout';
  static const libraryReturn = 'library.return';
  static const libraryProgress = 'library.progress';
  static const libraryFavoriteAdd = 'library.favorite.add';
  static const libraryFavoriteRemove = 'library.favorite.remove';
  static const eduLessonComplete = 'edu.lesson.complete';

  /// Changes a person made on purpose: if the server refuses one later, they are told.
  /// Everything else (activity tracking, download records, favorites, preferences) is background
  /// bookkeeping that the next pull corrects — a refusal there is dropped silently.
  static const userVisible = {
    attendanceSessionStart,
    attendanceSessionEnd,
    attendanceRecord,
    attendanceSet,
    attendanceClear,
    attendanceBulk,
    eduAttendanceSet,
    eduAttendanceScan,
    borrowingCreate,
    borrowingReturn,
    reminderCreate,
    reminderUpdate,
    reminderDelete,
    projectTaskUpdate,
    libraryCheckout,
    libraryReturn,
    eduLessonComplete,
  };
}

/// What happened to a submitted operation.
class SyncOutcome {
  const SyncOutcome._(this.state, {this.code, this.server});
  const SyncOutcome.applied([Object? server]) : this._('applied', server: server);
  const SyncOutcome.queued() : this._('queued');
  const SyncOutcome.rejected(String? code) : this._('rejected', code: code);

  /// The server's copy changed since the phone last saw it: nothing was applied (server wins).
  const SyncOutcome.conflict([Object? server]) : this._('conflict', server: server);

  /// applied (on the server now) | queued (saved on the phone, sent when online) | rejected
  final String state;
  final String? code;
  final Object? server;

  bool get applied => state == 'applied';
  bool get queued => state == 'queued';
  bool get rejected => state == 'rejected';
  bool get conflict => state == 'conflict';
}

/// An offline operation the server refused when it was finally sent (shown to the user).
class SyncRejection {
  const SyncRejection(this.type, this.code, this.payload);
  final String type;
  final String? code;
  final Json payload;
}

/// Offline attendance the server could not apply as captured: kept (with its signature) in the
/// HR review queue instead of being dropped.
class SyncHeldForReview {
  const SyncHeldForReview(this.type, this.code, this.payload);
  final String type;
  final String? code;
  final Json payload;
}

/// Called with the server's copy when an op is reported as a conflict (server data wins).
typedef ConflictHandler = Future<void> Function(Json payload, Object? serverCopy);

/// Queued payloads that carry a signature are kept encrypted (AES-256-GCM, key in the platform
/// keystore) until they are sent; everything else stays plain JSON.
abstract final class QueueSeal {
  static const _keyName = 'sync_queue_key';
  static const _storage = FlutterSecureStorage();
  static Uint8List? _key;

  static bool needsSeal(Json payload) => payload['signature'] != null || payload['signatures'] != null;

  static Future<Uint8List> _keyBytes() async {
    if (_key != null) return _key!;
    final existing = await _storage.read(key: _keyName);
    if (existing != null) return _key = base64Decode(existing);
    final r = Random.secure();
    final k = Uint8List.fromList(List.generate(32, (_) => r.nextInt(256)));
    await _storage.write(key: _keyName, value: base64Encode(k));
    return _key = k;
  }

  static Future<String> encode(Json payload, {bool force = false}) async {
    final plain = jsonEncode(payload);
    if (!force && !needsSeal(payload)) return plain;
    try {
      final sealed = BookVault.encrypt(Uint8List.fromList(utf8.encode(plain)), await _keyBytes());
      return jsonEncode({'_sealed': base64Encode(sealed)});
    } catch (e) {
      // No keystore on this device: keep it rather than lose a signed record.
      debugPrint('sync: could not seal a queued payload ($e)');
      return plain;
    }
  }

  static Future<Json> decode(String raw) async {
    final j = asJson(jsonDecode(raw));
    final sealed = j['_sealed'];
    if (sealed is! String) return j;
    final plain = BookVault.decrypt(base64Decode(sealed), await _keyBytes());
    return asJson(jsonDecode(utf8.decode(plain)));
  }
}

/// Offline-first write queue. Every user write that must survive being offline goes through
/// [enqueue]; [flush] replays the queue in order when online. Each op has a client UUID, so a
/// retried batch never duplicates records (the server keeps receipts).
class SyncService {
  SyncService(this._ref);
  final Ref _ref;
  final _conflictHandlers = <String, ConflictHandler>{};
  Future<void>? _inFlight;
  Timer? _timer;

  /// Emits after each successful flush so dependent state (reminders, favorites) can refresh.
  final _flushed = StreamController<void>.broadcast();
  Stream<void> get onFlushed => _flushed.stream;

  /// Offline operations the server rejected when they were replayed.
  final _rejected = StreamController<SyncRejection>.broadcast();
  Stream<SyncRejection> get onRejected => _rejected.stream;

  /// Offline attendance that went to the HR review queue when it was sent.
  final _held = StreamController<SyncHeldForReview>.broadcast();
  Stream<SyncHeldForReview> get onHeldForReview => _held.stream;

  /// Outcomes of ops being awaited by [submit], keyed by op id.
  final _outcomes = <String, SyncOutcome>{};
  final _awaited = <String>{};

  void onConflict(String type, ConflictHandler h) => _conflictHandlers[type] = h;

  Future<void> enqueue(String type, Json payload) async {
    await _insert(type, payload);
    unawaited(flush());
  }

  Future<String> _insert(String type, Json payload) async {
    final id = const Uuid().v4();
    final uid = _ref.read(currentUserProvider)?.id;
    await _ref.read(localDbProvider).db.insert('sync_queue', {
      'op_id': id,
      'user_id': uid,
      'type': type,
      'payload': await QueueSeal.encode(payload),
      'client_ts': DateTime.now().toUtc().toIso8601String(),
    });
    _flushed.add(null);
    return id;
  }

  /// Save an operation and try to send it right away. Online it is applied on the server (exactly
  /// once, even if the connection drops mid-request); offline — or on a flaky connection — it stays
  /// queued on the phone and is sent automatically when the connection is back.
  Future<SyncOutcome> submit(String type, Json payload) async {
    final id = await _insert(type, payload);
    _awaited.add(id);
    try {
      for (var attempt = 0; attempt < 2 && !_outcomes.containsKey(id); attempt++) {
        // A flush that was already running may not include this op: try once more after it.
        await flush().timeout(const Duration(seconds: 25), onTimeout: () {});
      }
      return _outcomes.remove(id) ?? const SyncOutcome.queued();
    } finally {
      _awaited.remove(id);
      _outcomes.remove(id);
    }
  }

  /// Payloads of queued (not yet sent) operations of [type] — lets screens show offline work.
  Future<List<Json>> pending(String type, {int? userId}) async {
    final uid = userId ?? _ref.read(currentUserProvider)?.id;
    final rows = uid != null
        ? await _ref.read(localDbProvider).db.query('sync_queue', where: 'type = ? AND (user_id = ? OR user_id IS NULL)', whereArgs: [type, uid], orderBy: 'rowid')
        : await _ref.read(localDbProvider).db.query('sync_queue', where: 'type = ?', whereArgs: [type], orderBy: 'rowid');
    final out = <Json>[];
    for (final r in rows) {
      try {
        out.add(await QueueSeal.decode(r['payload'] as String));
      } catch (_) {
        // Unreadable sealed payload (keystore reset): still sent and judged by the server below.
      }
    }
    return out;
  }

  Future<int> pendingCount({int? userId}) async {
    final uid = userId ?? _ref.read(currentUserProvider)?.id;
    final r = uid != null
        ? await _ref.read(localDbProvider).db.rawQuery('SELECT COUNT(*) AS c FROM sync_queue WHERE user_id = ? OR user_id IS NULL', [uid])
        : await _ref.read(localDbProvider).db.rawQuery('SELECT COUNT(*) AS c FROM sync_queue');
    return (r.first['c'] as int?) ?? 0;
  }

  bool get isFlushing => _inFlight != null;

  Future<List<SyncQueueItem>> getPendingQueueItems({int? userId}) async {
    final uid = userId ?? _ref.read(currentUserProvider)?.id;
    final rows = uid != null
        ? await _ref.read(localDbProvider).db.query('sync_queue', where: 'user_id = ? OR user_id IS NULL', whereArgs: [uid], orderBy: 'rowid')
        : await _ref.read(localDbProvider).db.query('sync_queue', orderBy: 'rowid');
    final out = <SyncQueueItem>[];
    for (final r in rows) {
      try {
        final payload = await QueueSeal.decode(r['payload'] as String);
        out.add(SyncQueueItem(
          opId: r['op_id'] as String,
          type: r['type'] as String,
          clientTs: DateTime.tryParse(r['client_ts'] as String? ?? '') ?? DateTime.now(),
          payload: payload,
        ));
      } catch (_) {}
    }
    return out;
  }

  void start() {
    _timer ??= Timer.periodic(const Duration(minutes: 5), (_) => unawaited(flush()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Replay the queue. Concurrent callers share (and await) the same in-flight flush.
  Future<void> flush() {
    if (_inFlight != null) return _inFlight!;
    if (_ref.read(sessionProvider) is! SignedIn) return Future.value();
    if (!_ref.read(isOnlineProvider)) return Future.value();
    return _inFlight = _flush().whenComplete(() => _inFlight = null);
  }

  Future<void> _flush() async {
    final db = _ref.read(localDbProvider).db;
    final api = _ref.read(apiClientProvider);
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    final uid = user.id;
    try {
      for (;;) {
        // Small batches: attendance and borrowing ops can carry a signature image.
        final rows = await db.query(
          'sync_queue',
          where: 'user_id = ? OR user_id IS NULL',
          whereArgs: [uid],
          orderBy: 'rowid',
          limit: 10,
        );
        if (rows.isEmpty) break;
        final ops = <Map<String, Object?>>[];
        for (final r in rows) {
          Object? payload;
          try {
            payload = await QueueSeal.decode(r['payload'] as String);
          } catch (e) {
            // The keystore lost the key: nothing can recover this payload; report it, don't loop.
            debugPrint('sync: unreadable sealed op ${r['type']} ($e)');
            if (SyncOp.userVisible.contains(r['type'])) _rejected.add(SyncRejection(r['type'] as String, 'LOCAL_DATA_UNREADABLE', const {}));
            await db.delete('sync_queue', where: 'op_id = ?', whereArgs: [r['op_id']]);
            continue;
          }
          ops.add({'op_id': r['op_id'], 'type': r['type'], 'payload': payload, 'client_ts': r['client_ts']});
        }
        if (ops.isEmpty) continue;
        // The phone's clock now, so the server can correct capture times by the phone's clock skew.
        final res = await api.post<Json>('/sync', body: {'operations': ops, 'client_now': DateTime.now().toUtc().toIso8601String()}, parse: asJson);
        var retryLater = false;
        for (final result in asJsonList(res['results'])) {
          final opId = result['op_id'] as String;
          final status = result['status'] as String;
          final op = ops.firstWhere((o) => o['op_id'] == opId);
          if (status == 'retry') {
            retryLater = true;
            await db.rawUpdate('UPDATE sync_queue SET attempts = attempts + 1 WHERE op_id = ?', [opId]);
            continue;
          }
          if (status == 'conflict') {
            final handler = _conflictHandlers[op['type']];
            if (handler != null) await handler(asJson(op['payload']), result['server']);
          }
          final code = result['code'] as String? ?? asJson(result['result'])['code'] as String?;
          final failed = status == 'rejected' || (status == 'duplicate' && result['original_status'] == 'rejected');
          if (_awaited.contains(opId)) {
            final server = result['server'] ?? asJson(result['result'])['server'];
            _outcomes[opId] = failed
                ? SyncOutcome.rejected(code)
                : (status == 'conflict' || (status == 'duplicate' && result['original_status'] == 'conflict'))
                    ? SyncOutcome.conflict(server)
                    : SyncOutcome.applied(server);
          } else if (failed && SyncOp.userVisible.contains(op['type'])) {
            _rejected.add(SyncRejection(op['type'] as String, code, asJson(op['payload'])));
          } else if (status == 'conflict' && ((op['type'] as String).startsWith('attendance.') || (op['type'] as String).startsWith('library.'))) {
            final server = asJson(result['server']);
            _held.add(SyncHeldForReview(op['type'] as String, server['code'] as String?, asJson(op['payload'])));
          } else if (failed) {
            debugPrint('sync: background op ${op['type']} refused (${code ?? '?'}) — dropped');
          }
          // applied | duplicate | rejected | conflict → done with this op.
          await db.delete('sync_queue', where: 'op_id = ?', whereArgs: [opId]);
        }
        if (retryLater) break;
      }
      final now = DateTime.now();
      await _ref.read(localPrefsProvider).setLastSuccessfulSync(now);
      _flushed.add(null);
    } catch (e) {
      debugPrint('sync flush failed: $e');
      _flushed.add(null);
    }
  }

  /// Convenience for client-reported activity (audio played, offline access…).
  Future<void> trackActivity(String action, {String? entityType, int? entityId, Map<String, Object>? metadata}) =>
      enqueue(SyncOp.activity, {
        'action': action,
        'entity_type': ?entityType,
        'entity_id': ?entityId,
        'metadata': ?metadata,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      });
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final s = SyncService(ref);
  ref.onDispose(s.stop);
  return s;
});

/// Keeps a typed reference to the API client for services that are not providers themselves.
ApiClient apiOf(Ref ref) => ref.read(apiClientProvider);
