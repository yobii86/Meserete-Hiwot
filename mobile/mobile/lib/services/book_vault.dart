import 'dart:convert';
import 'dart:io' show Directory, File, Platform;
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';

/// Downloaded library books, readable inside the app.
///
/// On mobile/desktop: A book's PDF is downloaded into memory, encrypted with AES-256-GCM and written to the app's
/// private support directory (`books/book_<id>.bin`). The key is created on first use and kept in
/// the platform keystore (flutter_secure_storage).
/// On Web (or as fallback): In-memory cache is used safely without file system dependency.
class BookVault {
  BookVault._();

  static const _keyName = 'book_vault_key';
  static const _nonceLength = 12;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final Map<int, Uint8List> _memCache = {};

  static bool get isTest => Platform.environment.containsKey('FLUTTER_TEST');

  static Future<Directory> _dir() async {
    if (isTest) {
      final dir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}books_cache');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    }
    try {
      final supportDir = await getApplicationSupportDirectory();
      final dir = Directory('${supportDir.path}${Platform.pathSeparator}books');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    } catch (_) {
      final dir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}books_cache');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    }
  }

  static Future<File> fileFor(int bookId) async => File('${(await _dir()).path}${Platform.pathSeparator}book_$bookId.bin');

  static Future<bool> has(int bookId) async {
    if (_memCache.containsKey(bookId)) return true;
    if (kIsWeb) return false;
    try {
      return (await fileFor(bookId)).existsSync();
    } catch (_) {
      return false;
    }
  }

  static Future<Uint8List> _key({bool create = true}) async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) return base64Decode(existing);
    if (!create) throw const BookVaultException();
    final key = _random(32);
    await _storage.write(key: _keyName, value: base64Encode(key));
    return key;
  }

  static Uint8List _random(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  /// nonce (12 bytes) · ciphertext · GCM tag (16 bytes).
  static Uint8List encrypt(Uint8List plain, Uint8List key) {
    final nonce = _random(_nonceLength);
    final c = GCMBlockCipher(AESEngine())..init(true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
    return Uint8List.fromList([...nonce, ...c.process(plain)]);
  }

  static Uint8List decrypt(Uint8List sealed, Uint8List key) {
    if (sealed.length <= _nonceLength + 16) throw const BookVaultException();
    final c = GCMBlockCipher(AESEngine())..init(false, AEADParameters(KeyParameter(key), 128, sealed.sublist(0, _nonceLength), Uint8List(0)));
    try {
      return c.process(sealed.sublist(_nonceLength));
    } on InvalidCipherTextException {
      throw const BookVaultException();
    }
  }

  /// Encrypt and keep a downloaded PDF.
  static Future<void> save(int bookId, Uint8List pdf) async {
    _memCache[bookId] = pdf;
    if (kIsWeb) return;
    try {
      final sealed = encrypt(pdf, await _key());
      final f = await fileFor(bookId);
      final tmp = File('${f.path}.part');
      await tmp.writeAsBytes(sealed, flush: true);
      await tmp.rename(f.path);
    } catch (_) {
      // In-memory cache ensures reader still opens even if disk write fails
    }
  }

  /// The PDF in memory for the reader.
  static Future<Uint8List> read(int bookId) async {
    if (_memCache.containsKey(bookId)) return _memCache[bookId]!;
    if (kIsWeb) throw const BookVaultException();
    try {
      final f = await fileFor(bookId);
      if (!f.existsSync()) throw const BookVaultException();
      final bytes = decrypt(await f.readAsBytes(), await _key(create: false));
      _memCache[bookId] = bytes;
      return bytes;
    } on BookVaultException {
      try {
        final f = await fileFor(bookId);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
      rethrow;
    } catch (_) {
      throw const BookVaultException();
    }
  }

  static Future<void> remove(int bookId) async {
    _memCache.remove(bookId);
    if (kIsWeb) return;
    try {
      final f = await fileFor(bookId);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }

  static Future<List<int>> listDownloadedIds() async {
    final ids = <int>{..._memCache.keys};
    if (kIsWeb) return ids.toList();
    try {
      final dir = await _dir();
      if (dir.existsSync()) {
        for (final entry in dir.listSync()) {
          final match = RegExp(r'book_(\d+)\.bin$').firstMatch(entry.path);
          if (match != null) {
            final id = int.tryParse(match.group(1)!);
            if (id != null) ids.add(id);
          }
        }
      }
    } catch (_) {}
    return ids.toList();
  }

  /// Delete every downloaded book and the key (sign-out).
  static Future<void> wipe() async {
    _memCache.clear();
    if (kIsWeb) return;
    try {
      final dir = await _dir();
      if (dir.existsSync()) await dir.delete(recursive: true);
      final old = Directory('${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}books');
      if (old.existsSync()) await old.delete(recursive: true);
      await _storage.delete(key: _keyName);
    } catch (_) {
      // Best effort
    }
  }
}

class BookVaultException implements Exception {
  const BookVaultException();
}
