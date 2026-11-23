import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/session.dart';
import '../models/admin.dart';
import '../services/sync_service.dart';
import 'network/api_client.dart';
import 'network/api_exception.dart';
import 'storage/local_db.dart';
import 'storage/local_prefs.dart';
import 'storage/secure_store.dart';

/// Initialised in main() and injected with ProviderScope overrides.
final secureStoreProvider = Provider<SecureStore>((ref) => throw UnimplementedError('secureStoreProvider not initialised'));
final localDbProvider = Provider<LocalDb>((ref) => throw UnimplementedError('localDbProvider not initialised'));
final localPrefsProvider = Provider<LocalPrefs>((ref) => throw UnimplementedError('localPrefsProvider not initialised'));

final apiClientProvider = Provider<ApiClient>((ref) {
  final api = ApiClient(ref.watch(secureStoreProvider));
  final db = ref.watch(localDbProvider);
  unawaited(db.pruneHttpCache().catchError((Object _) => 0));
  // Offline copies live in the per-user cache table (wiped on logout).
  api.cache = DbResponseCache(db, ref);
  api.isOffline = () => !ref.read(isOnlineProvider);
  return api;
});

ResponseCache createDbResponseCache(LocalDb db, Ref ref) => DbResponseCache(db, ref);

class DbResponseCache implements ResponseCache {
  DbResponseCache(this._db, this._ref);
  final LocalDb _db;
  final Ref _ref;

  static const _protectedPrefixes = [
    '/admin',
    '/edu/admin',
    '/reports',
    '/attendance/',
    '/payments',
    '/selections',
    '/users',
  ];

  static bool isProtectedPath(String path) => _protectedPrefixes.any(path.startsWith);

  static String requiredPermissionFor(String path) {
    if (path.startsWith('/edu/admin/attendance')) return Perm.educationAttendanceView;
    if (path.startsWith('/edu/admin')) return Perm.educationManage;
    if (path.startsWith('/admin/selections') || path.startsWith('/selections')) return Perm.selectionView;
    if (path.startsWith('/admin/reports') || path.startsWith('/reports')) return Perm.reportsView;
    if (path.startsWith('/attendance/')) return Perm.attendanceView;
    if (path.startsWith('/payments')) return Perm.paymentsView;
    if (path.startsWith('/admin/users') || path.startsWith('/users')) return Perm.usersView;
    if (path.startsWith('/admin/admins') || path.startsWith('/admins')) return Perm.adminsView;
    if (path.startsWith('/admin/programs') || path.startsWith('/programs')) return Perm.programsManage;
    if (path.startsWith('/admin')) return Perm.adminsView;
    return '';
  }

  static String _extractPath(String key) {
    if (!key.startsWith('http:')) return key;
    final after = key.substring(5);
    final qIndex = after.indexOf('?');
    return qIndex == -1 ? after : after.substring(0, qIndex);
  }

  @override
  Future<void> put(String key, Object? body) async {
    try {
      final path = _extractPath(key);
      if (isProtectedPath(path)) {
        final user = _ref.read(currentUserProvider);
        final reqPerm = requiredPermissionFor(path);
        final perms = user?.permissions.toList() ?? <String>[];
        perms.sort();
        final permHash = md5.convert(utf8.encode(perms.join(','))).toString();

        final rawPayload = body is Map<String, dynamic> ? body : {'_data': body};
        final encoded = await QueueSeal.encode(rawPayload, force: true);
        await _db.putCache(key, encoded, isSealed: true, permHash: permHash, requiredPerm: reqPerm);
      } else {
        await _db.putCache(key, body ?? const {}, isSealed: false);
      }
    } catch (_) {}
  }

  @override
  Future<Object?> get(String key) async {
    try {
      final row = await _db.getCacheRow(key);
      if (row == null) return null;

      final isSealed = row['is_sealed'] == 1;
      if (!isSealed) {
        final raw = row['json'] as String;
        return jsonDecode(raw);
      }

      // Sealed row: role and permission check
      final user = _ref.read(currentUserProvider);
      final reqPerm = row['required_perm'] as String? ?? '';

      // If user is logged out or lost their required permission, refuse the read
      final hasPerm = user != null &&
          (reqPerm.isEmpty ||
              user.can(reqPerm) ||
              user.permissions.contains(reqPerm) ||
              user.roleLevel == 100);

      if (!hasPerm) {
        throw const ApiException(
          status: 403,
          code: 'NOT_AVAILABLE_FOR_ACCOUNT',
          message: 'Not available for your account',
        );
      }

      // Decrypt sealed content
      final raw = row['json'] as String;
      try {
        final decoded = await QueueSeal.decode(raw);
        if (decoded.containsKey('_data') && decoded.length == 1) {
          return decoded['_data'];
        }
        return decoded;
      } catch (e) {
        // Keystore key lost or decryption failed: drop stale row and return null
        await _db.db.delete('cache', where: 'key = ?', whereArgs: [key]);
        return null;
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }
}

/// true when the device has any network connection.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool online(List<ConnectivityResult> r) => r.any((e) => e != ConnectivityResult.none);
  yield online(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(online);
});

final isOnlineProvider = Provider<bool>((ref) => ref.watch(connectivityProvider).value ?? true);

/// Whether the current connection is Wi-Fi/ethernet (for "download on Wi-Fi only").
Future<bool> isUnmeteredConnection() async {
  final r = await Connectivity().checkConnectivity();
  return r.contains(ConnectivityResult.wifi) || r.contains(ConnectivityResult.ethernet);
}

// ---------------------------------------------------------------------------
// Device-level app settings (language, theme, download policy).
// ---------------------------------------------------------------------------
class AppSettings {
  const AppSettings({required this.locale, required this.themeMode, required this.wifiOnly, required this.lyricsScale});
  final Locale locale;
  final ThemeMode themeMode;
  final bool wifiOnly;
  final double lyricsScale;

  AppSettings copyWith({Locale? locale, ThemeMode? themeMode, bool? wifiOnly, double? lyricsScale}) => AppSettings(
        locale: locale ?? this.locale,
        themeMode: themeMode ?? this.themeMode,
        wifiOnly: wifiOnly ?? this.wifiOnly,
        lyricsScale: lyricsScale ?? this.lyricsScale,
      );
}

class AppSettingsController extends Notifier<AppSettings> {
  LocalPrefs get _prefs => ref.read(localPrefsProvider);

  @override
  AppSettings build() {
    final p = ref.watch(localPrefsProvider);
    return AppSettings(
      locale: Locale(p.localeCode),
      themeMode: switch (p.theme) { 'dark' => ThemeMode.dark, 'system' => ThemeMode.system, _ => ThemeMode.light },
      wifiOnly: p.wifiOnly,
      lyricsScale: p.lyricsScale,
    );
  }

  Future<void> setLocale(String code) async {
    await _prefs.setLocaleCode(code);
    state = state.copyWith(locale: Locale(code));
  }

  Future<void> setDark(bool dark) async {
    await _prefs.setTheme(dark ? 'dark' : 'light');
    state = state.copyWith(themeMode: dark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setWifiOnly(bool v) async {
    await _prefs.setWifiOnly(v);
    state = state.copyWith(wifiOnly: v);
  }

  Future<void> setLyricsScale(double v) async {
    final clamped = v.clamp(0.8, 1.8).toDouble();
    await _prefs.setLyricsScale(clamped);
    state = state.copyWith(lyricsScale: clamped);
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsController, AppSettings>(AppSettingsController.new);
