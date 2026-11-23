import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../storage/secure_store.dart';
import '../../models/json.dart';
import 'api_exception.dart';
import 'file_upload_helper.dart';

import 'imunify_solver.dart';

/// One page of a paginated list endpoint.
class Paged<T> {
  const Paged({required this.items, required this.page, required this.pages, required this.total, this.meta = const {}});
  final List<T> items;
  final int page;
  final int pages;
  final int total;
  final Map<String, dynamic> meta;
  bool get hasMore => page < pages;
}

/// Last good response of GET requests (per signed-in user), shown when the network fails.
abstract class ResponseCache {
  Future<void> put(String key, Object? body);
  Future<Object?> get(String key);
}

/// Thin wrapper over Dio: bearer auth, transparent (single-flight) token refresh,
/// envelope unwrapping and error normalisation into [ApiException].
///
/// Flaky connections: GETs are retried on connection drops / timeouts and, if the network still
/// fails, answered from the last good copy ([cache]) instead of showing a timeout error.
class ApiClient {
  ApiClient(this._store, {Dio? dio, String? baseUrl})
      : dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.receiveTimeout,
              headers: {
                'Accept': 'application/json',
                'User-Agent': 'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36',
              },
            )) {
    final cachedCookie = _store.imunifyCookie;
    if (cachedCookie != null && cachedCookie.isNotEmpty) {
      _imunifyCookie = cachedCookie;
      this.dio.options.headers['Cookie'] = cachedCookie;
    }
    this.dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  final Dio dio;
  final SecureStore _store;
  Completer<bool>? _refreshing;
  static String? _imunifyCookie;
  Completer<String?>? _imunifySolving;

  /// Offline copies of GET responses (null in tests).
  ResponseCache? cache;

  /// True when the phone knows it has no connection: cached answers are used without waiting.
  bool Function()? isOffline;

  /// Delays between GET retries after a dropped connection / timeout.
  List<Duration> retryDelays = const [Duration(milliseconds: 700), Duration(milliseconds: 1800)];

  static bool _transient(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      (e.type == DioExceptionType.unknown && e.response == null);

  // Delta endpoints (?since=…) must never be answered from an old copy.
  static const _noCache = ['/auth/', '/system/auth/', '/app/version', '/sync', '/reminders', '/favorites/sync'];

  static String _cacheKey(String path, Map<String, dynamic>? q) {
    final keys = (q?.keys.toList() ?? <String>[])..sort();
    return 'http:$path?${keys.map((k) => '$k=${q![k]}').join('&')}';
  }

  /// Solves the Imunify360 Anti-Bot challenge in a single flight and saves the splash cookie.
  Future<String?> _solveImunify() async {
    if (_imunifySolving != null) return _imunifySolving!.future;
    final c = _imunifySolving = Completer<String?>();
    try {
      final baseUri = Uri.parse(dio.options.baseUrl);
      final origin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
      final cookie = await ImunifySolver.solve(origin);
      if (cookie != null) {
        _imunifyCookie = cookie;
        dio.options.headers['Cookie'] = cookie;
        unawaited(_store.saveImunifyCookie(cookie));
      }
      c.complete(cookie);
    } catch (_) {
      c.complete(null);
    } finally {
      _imunifySolving = null;
    }
    return c.future;
  }

  /// Ensures an Imunify challenge cookie is resolved if none is cached yet.
  Future<String?> ensureImunifyResolved() async {
    if (_imunifyCookie == null || _imunifyCookie!.isEmpty) {
      return _solveImunify();
    }
    return _imunifyCookie;
  }

  /// GET with retries on transient failures; falls back to the cached body when still failing.
  /// Returns the response body (the backend envelope) and whether it came from the cache.
  Future<(Object?, bool)> _resilientGet(String path, Map<String, dynamic>? q, {Options? options}) async {
    final key = _cacheKey(path, q);
    final cacheable = cache != null && !_noCache.any(path.startsWith);
    if (cacheable && (isOffline?.call() ?? false)) {
      final hit = await cache!.get(key);
      if (hit != null) return (hit, true);
    }
    for (var attempt = 0; ; attempt++) {
      try {
        final res = await dio.get(path, queryParameters: q, options: options);
        if (cacheable && res.data is Map && (res.data as Map)['success'] == true) unawaited(cache!.put(key, res.data));
        return (res.data as Object?, false);
      } on DioException catch (e) {
        if (_transient(e) && attempt < retryDelays.length && !(isOffline?.call() ?? false)) {
          await Future<void>.delayed(retryDelays[attempt]);
          continue;
        }
        if (cacheable && _transient(e)) {
          final hit = await cache!.get(key);
          if (hit != null) return (hit, true);
        }
        rethrow;
      }
    }
  }

  /// Called when the session can no longer be refreshed (revoked, device reset, expired).
  void Function()? onSessionExpired;

  /// Called when the server refuses an action (403): the account's permissions may have changed
  /// (e.g. one was revoked), so the app reloads them and hides what is no longer allowed.
  void Function()? onForbidden;

  static const _authFreePaths = ['/auth/login', '/auth/register', '/auth/refresh', '/auth/forgot-password', '/auth/reset-password', '/system/auth/'];

  void _onRequest(RequestOptions o, RequestInterceptorHandler h) {
    final token = _store.accessToken;
    final free = _authFreePaths.any((p) => o.path.startsWith(p));
    if (token != null && !free) o.headers['Authorization'] = 'Bearer $token';
    if (_imunifyCookie != null) o.headers['Cookie'] = _imunifyCookie;
    h.next(o);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler h) async {
    final res = e.response;
    final isRetry = e.requestOptions.extra['retried'] == true;
    final isImunifyRetry = e.requestOptions.extra['imunify_retried'] == true;

    // Check for Imunify360 Anti-Bot challenge block
    final isImunify = !isImunifyRetry &&
        ((res?.statusCode == 403 && (res?.data.toString().contains('Imunify360') ?? false)) ||
         (res?.statusCode == 403 && (res?.data.toString().contains('bot-protection') ?? false)) ||
         (res?.data.toString().contains('wsidchk') ?? false) ||
         (res?.data.toString().contains('One moment, please...') ?? false));

    if (isImunify) {
      try {
        dio.httpClientAdapter.close(force: true);
      } catch (_) {}
      final cookie = await _solveImunify();
      if (cookie != null) {
        try {
          final opts = e.requestOptions
            ..extra['imunify_retried'] = true
            ..headers['Cookie'] = cookie;
          return h.resolve(await dio.fetch(opts));
        } on DioException catch (err) {
          return h.next(err);
        }
      }
    }

    final code = res?.data is Map ? (res!.data as Map)['code'] : null;
    // An expired or unreadable access token is simply replaced: the session itself goes on.
    final refreshable = res?.statusCode == 401 && (code == 'TOKEN_EXPIRED' || code == 'INVALID_TOKEN') && !isRetry && _store.refreshToken != null;
    if (!refreshable) {
      if (res?.statusCode == 401 && ApiException.sessionEndingCodes.contains(code)) {
        onSessionExpired?.call();
      }
      if (res?.statusCode == 403 && e.requestOptions.path != '/me' && !e.requestOptions.path.contains('/auth/login')) onForbidden?.call();
      return h.next(e);
    }
    final ok = await _refresh();
    if (!ok) {
      // Never sign out here: a refresh that failed on a dropped connection, a timeout or a server
      // error keeps the session for the next try. A real rejection (revoked, reset, theft) already
      // ended it in the refresh request's own 401 handling above.
      return h.next(e);
    }
    try {
      final opts = e.requestOptions
        ..extra['retried'] = true
        ..headers['Authorization'] = 'Bearer ${_store.accessToken}';
      if (_imunifyCookie != null) opts.headers['Cookie'] = _imunifyCookie;
      h.resolve(await dio.fetch(opts));
    } on DioException catch (err) {
      h.next(err);
    }
  }

  /// Rotates the refresh token. Concurrent 401s share one refresh call. False on any failure; only
  /// the server's explicit 401 rejection of the refresh token ends the session.
  Future<bool> _refresh() async {
    if (_refreshing != null) return _refreshing!.future;
    final c = _refreshing = Completer<bool>();
    try {
      final scope = _store.scope;
      final path = scope == 'system' ? '/system/auth/refresh' : '/auth/refresh';
      final res = await dio.post(path, data: {'refresh_token': _store.refreshToken, 'device_id': await _store.deviceId()},
          options: Options(extra: {'retried': true}));
      final data = res.data['data'] as Json;
      await _store.saveTokens(access: data['access_token'] as String, refresh: data['refresh_token'] as String, scope: scope);
      c.complete(true);
    } catch (_) {
      c.complete(false);
    } finally {
      _refreshing = null;
    }
    return c.future;
  }

  // ---------------------------------------------------------------------------
  Future<T> _call<T>(Future<Response<dynamic>> Function() req, T Function(dynamic data) parse) async {
    try {
      final res = await req();
      final body = res.data;
      if (body is Map && body['success'] == true) return parse(body['data']);
      return parse(body);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  static ApiException _toApiException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(code: ApiException.timeout);
      case DioExceptionType.connectionError:
        return const ApiException(code: ApiException.network);
      case DioExceptionType.cancel:
        return const ApiException(code: ApiException.cancelled);
      default:
        break;
    }
    final res = e.response;
    if (res == null) return const ApiException(code: ApiException.network);
    final body = res.data;
    if (body is Map) {
      final errors = <String, String>{};
      final fieldMessages = <String, String>{};
      for (final err in (body['errors'] as List? ?? const [])) {
        if (err is Map && err['field'] != null) {
          final fName = err['field'] as String;
          errors[fName] = (err['code'] ?? 'INVALID_VALUE') as String;
          if (err['message'] != null && (err['message'] as String).isNotEmpty) {
            fieldMessages[fName] = err['message'] as String;
          }
        }
      }
      return ApiException(
        code: (body['code'] as String?) ?? ApiException.unknown,
        status: res.statusCode,
        message: body['message'] as String?,
        fieldErrors: errors,
        fieldMessages: fieldMessages,
        serverData: body['errors'],
      );
    }
    return ApiException(code: ApiException.unknown, status: res.statusCode);
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query, T Function(dynamic data)? parse}) async {
    final p = parse ?? (d) => d as T;
    try {
      final (body, _) = await _resilientGet(path, _clean(query));
      if (body is Map && body['success'] == true) return p(body['data']);
      return p(body);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<T> post<T>(String path, {Object? body, T Function(dynamic data)? parse}) =>
      _call(() => dio.post(path, data: body ?? const {}), parse ?? (d) => d as T);

  Future<T> put<T>(String path, {Object? body, T Function(dynamic data)? parse}) =>
      _call(() => dio.put(path, data: body ?? const {}), parse ?? (d) => d as T);

  Future<T> patch<T>(String path, {Object? body, T Function(dynamic data)? parse}) =>
      _call(() => dio.patch(path, data: body ?? const {}), parse ?? (d) => d as T);

  Future<T> delete<T>(String path, {Object? body, Map<String, dynamic>? query, T Function(dynamic data)? parse}) =>
      _call(() => dio.delete(path, data: body, queryParameters: _clean(query)), parse ?? (d) => d as T);

  /// GET a paginated list. `meta` carries page/limit/total/pages (+ endpoint extras).
  Future<Paged<T>> getPage<T>(String path, T Function(Json json) item, {Map<String, dynamic>? query, int page = 1, int? limit}) async {
    try {
      final (raw, cached) = await _resilientGet(path, _clean({...?query, 'page': page, 'limit': limit ?? AppConfig.pageSize}));
      final body = raw as Map;
      final meta = {...(body['meta'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}, if (cached) 'offline': true};
      final list = (body['data'] as List).cast<Map>().map((m) => item(m.cast<String, dynamic>())).toList();
      return Paged(
        items: list,
        page: (meta['page'] as num?)?.toInt() ?? page,
        pages: (meta['pages'] as num?)?.toInt() ?? 1,
        total: (meta['total'] as num?)?.toInt() ?? list.length,
        meta: meta,
      );
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// Multipart upload of one file field (`file`).
  /// Upload a file streamed from disk on mobile, or from memory bytes on Web, with progress.
  Future<T> upload<T>(
    String path, {
    required String filePath,
    Uint8List? fileBytes,
    String? filename,
    Map<String, dynamic>? fields,
    T Function(dynamic data)? parse,
    void Function(double)? onProgress,
  }) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await _call(() async {
          final resolvedFilename = filename ?? filePath.split(RegExp(r'[/\\]')).last;
          MultipartFile multipart;

          final cachedBytes = fileBytes ?? getUploadBytes(filePath);
          if (cachedBytes != null) {
            multipart = MultipartFile.fromBytes(cachedBytes, filename: resolvedFilename);
          } else if (kIsWeb) {
            try {
              final bytes = await XFile(filePath).readAsBytes();
              multipart = MultipartFile.fromBytes(bytes, filename: resolvedFilename);
            } catch (_) {
              throw ApiException(code: 'FILE_READ_FAILED', message: 'Cannot read file for web upload: $filePath');
            }
          } else {
            multipart = await MultipartFile.fromFile(filePath, filename: resolvedFilename);
          }

          final form = FormData.fromMap({
            ...?fields,
            'file': multipart,
          });
          final result = await dio.post(
            path,
            data: form,
            options: Options(sendTimeout: Duration.zero),
            onSendProgress: (s, t) => t > 0 ? onProgress?.call(s / t) : null,
          );
          clearUploadBytes(filePath);
          return result;
        }, parse ?? (d) => d as T);
      } on ApiException catch (e) {
        if (!e.isNetwork || attempt >= 2) rethrow;
        onProgress?.call(0);
        await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }
  }

  /// Download a file to [savePath] (used by offline downloads).
  Future<void> download(String url, String savePath, {void Function(int received, int total)? onProgress, CancelToken? cancel}) async {
    try {
      await dio.download(url, savePath, onReceiveProgress: onProgress, cancelToken: cancel);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// Download an authenticated file into memory (never written to disk), with progress.
  Future<Uint8List> downloadBytes(String url, {void Function(int received, int total)? onProgress, CancelToken? cancel}) async {
    try {
      final r = await dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes), onReceiveProgress: onProgress, cancelToken: cancel);
      final d = r.data ?? const <int>[];
      return d is Uint8List ? d : Uint8List.fromList(d);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// Raw bytes of an authenticated resource (e.g. a signature image).
  Future<List<int>> bytes(String path) => _call(
        () => dio.get<List<int>>(path, options: Options(responseType: ResponseType.bytes)),
        (d) => d as List<int>,
      );

  static Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    return Map.fromEntries(q.entries.where((e) => e.value != null && e.value != ''));
  }
}
