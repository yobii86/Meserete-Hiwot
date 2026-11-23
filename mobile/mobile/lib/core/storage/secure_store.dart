import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Tokens and the device identity live in the platform keystore — never in plain preferences.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;

  static const _access = 'access_token';
  static const _refresh = 'refresh_token';
  static const _scope = 'token_scope';
  static const _deviceId = 'device_id';
  static const _user = 'cached_user';
  static const _imunifyCookie = 'imunify_cookie';

  String? _accessCache;
  String? _refreshCache;
  String? _scopeCache;
  String? _imunifyCookieCache;

  Future<void> load() async {
    _accessCache = await _s.read(key: _access);
    _refreshCache = await _s.read(key: _refresh);
    _scopeCache = await _s.read(key: _scope);
    _imunifyCookieCache = await _s.read(key: _imunifyCookie);
  }

  String? get imunifyCookie => _imunifyCookieCache;

  Future<void> saveImunifyCookie(String cookie) async {
    _imunifyCookieCache = cookie;
    await _s.write(key: _imunifyCookie, value: cookie);
  }

  String? get accessToken => _accessCache;
  String? get token => _accessCache;
  String? get refreshToken => _refreshCache;

  /// 'app' for users/admins, 'system' for the internal system authority.
  String get scope => _scopeCache ?? 'app';
  bool get hasSession => _refreshCache != null;

  Future<void> saveTokens({required String access, required String refresh, String scope = 'app'}) async {
    _accessCache = access;
    _refreshCache = refresh;
    _scopeCache = scope;
    await _s.write(key: _access, value: access);
    await _s.write(key: _refresh, value: refresh);
    await _s.write(key: _scope, value: scope);
  }

  Future<void> clearTokens() async {
    _accessCache = null;
    _refreshCache = null;
    _scopeCache = null;
    await _s.delete(key: _access);
    await _s.delete(key: _refresh);
    await _s.delete(key: _scope);
    await _s.delete(key: _user);
  }

  /// Stable per-install device id used for the one-device-per-user rule.
  Future<String> deviceId() async {
    final existing = await _s.read(key: _deviceId);
    if (existing != null) return existing;
    final prefix = kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
    final id = '$prefix-${const Uuid().v4()}';
    await _s.write(key: _deviceId, value: id);
    return id;
  }

  Future<void> saveUserJson(String json) => _s.write(key: _user, value: json);
  Future<String?> readUserJson() => _s.read(key: _user);
}
