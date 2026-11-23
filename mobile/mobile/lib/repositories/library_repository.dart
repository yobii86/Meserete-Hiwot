// ignore_for_file: use_null_aware_elements
import 'dart:typed_data';

import '../core/network/api_client.dart';
import '../models/admin.dart';
import '../models/json.dart';
import '../models/library.dart';
import '../services/sync_service.dart';

/// The members' library (books, PDF downloads, requests), circulation (F17),
/// audio narration (F16), and student registration.
class LibraryRepository {
  LibraryRepository(this._api, [this._sync]);
  final ApiClient _api;
  final SyncService? _sync;

  // ---- members & digital library (F16) ----
  Future<Paged<Book>> books({
    String? domain,
    String? kind,
    String? q,
    String? category,
    int? categoryId,
    bool? favoritesOnly,
    String? language,
    bool? availableOnly,
    String? status,
    bool? includeDrafts,
    int page = 1,
  }) =>
      _api.getPage(
        '/library/books',
        Book.fromJson,
        page: page,
        query: {
          'domain': domain,
          'kind': kind,
          'q': q,
          'category': category,
          'category_id': categoryId,
          if (language != null && language != 'all') 'language': language,
          if (availableOnly == true) 'available_only': 'true',
          if (favoritesOnly == true) 'favorites_only': 'true',
          if (favoritesOnly == true) 'favorites': 1,
          if (status != null) 'status': status,
          if (includeDrafts == true) 'include_drafts': 'true',
        },
      );

  Future<Book> book(int id) => _api.get('/library/books/$id', parse: (d) => Book.fromJson(asJson(d)));

  Future<List<LibraryCategory>> categories({String? domain, String? type, bool? onlyActive, bool tree = false}) =>
      _api.get(
        '/library/categories',
        query: {
          'domain': domain,
          'type': ?type,
          if (onlyActive != null) 'only_active': onlyActive ? 1 : 0,
          if (tree) 'tree': 1,
        },
        parse: (d) => asJsonList(d).map(LibraryCategory.fromJson).toList(),
      );

  Future<LibraryCategory> saveCategory(Map<String, dynamic> body, {int? id}) => id != null
      ? _api.put('/library/categories/$id', body: body, parse: (d) => LibraryCategory.fromJson(asJson(d)))
      : _api.post('/library/categories', body: body, parse: (d) => LibraryCategory.fromJson(asJson(d)));

  Future<void> deleteCategory(int id) => _api.delete<void>('/library/categories/$id');

  Future<bool> toggleFavorite(int bookId, {bool? currentState}) async {
    final body = currentState != null ? {'is_favorite': !currentState} : null;
    try {
      final res = await _api.post<Json>('/library/books/$bookId/favorite', body: body, parse: asJson);
      return res['is_favorite'] == true || res['favorited'] == true;
    } catch (e) {
      if (currentState != null) {
        final next = !currentState;
        if (_sync != null) {
          await _sync.enqueue(
            next ? SyncOp.libraryFavoriteAdd : SyncOp.libraryFavoriteRemove,
            {'item_id': bookId},
          );
        }
        return next;
      }
      rethrow;
    }
  }

  Future<List<int>> getFavoriteBookIds() async {
    final res = await _api.get<Json>('/library/favorites', query: {'ids_only': 'true'});
    final list = res['ids'] as List<dynamic>? ?? [];
    return list.map((e) => asIntOr(e)).toList();
  }

  Future<void> saveProgress(
    int bookId, {
    int? page,
    int? pageCount,
    int? audioPositionMs,
  }) async {
    final payload = <String, dynamic>{
      'book_id': bookId,
      'page': ?page,
      'page_count': ?pageCount,
      'audio_position_ms': ?audioPositionMs,
    };
    if (_sync != null) {
      await _sync.enqueue(SyncOp.libraryProgress, payload);
    } else {
      await _api.post('/library/books/$bookId/progress', body: payload);
    }
  }

  Future<BookProgress> getProgress(int bookId) =>
      _api.get('/library/books/$bookId/progress', parse: (d) => BookProgress.fromJson(asJson(d)));

  /// A digital book's PDF, in memory (sent with the signed-in user's token). It is kept only
  /// encrypted (see BookVault) and opened in the in-app reader.
  Future<Uint8List> downloadBook(Book b, {void Function(int, int)? onProgress}) {
    String url = (b.fileUrl != null && b.fileUrl!.isNotEmpty)
        ? b.fileUrl!
        : '/library/books/${b.id}/file';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (!url.startsWith('/api/v1')) {
        url = '/api/v1/${url.replaceFirst(RegExp(r"^/+"), "")}';
      }
    }
    return _api.downloadBytes(url, onProgress: onProgress);
  }

  Future<BookRequest> request(int bookId, {String? note, String? neededOn}) =>
      _api.post('/library/books/$bookId/request', body: {'note': ?note, 'needed_on': ?neededOn}, parse: (d) => BookRequest.fromJson(asJson(d)));
  Future<Paged<BookRequest>> myRequests({int page = 1}) => _api.getPage('/library/requests/me', BookRequest.fromJson, page: page);
  Future<BookRequest> cancel(int id) => _api.delete('/library/requests/$id', parse: (d) => BookRequest.fromJson(asJson(d)));

  // ---- Physical circulation (F17) ----
  Future<Paged<LibraryCopy>> copies({String? q, String? status, int? itemId, int page = 1}) =>
      _api.getPage(
        '/library/circulation/copies',
        LibraryCopy.fromJson,
        page: page,
        query: {'q': q, 'status': status, 'item_id': itemId},
      );

  Future<LibraryCopy> findCopyByCode(String code) =>
      _api.get('/library/circulation/copies/by-code/$code', parse: (d) => LibraryCopy.fromJson(asJson(d)));

  Future<Paged<LibraryLoan>> loans({String? status, String? q, int page = 1}) =>
      _api.getPage(
        '/library/circulation/loans',
        LibraryLoan.fromJson,
        page: page,
        query: {'status': status, 'q': q},
      );

  Future<Paged<LibraryLoan>> overdue({int page = 1}) =>
      _api.getPage('/library/circulation/overdue', LibraryLoan.fromJson, page: page);

  Future<SyncOutcome> checkout({
    required int copyId,
    required int userId,
    required String signature,
    int? loanDays,
    String? conditionOut,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'copy_id': copyId,
      'user_id': userId,
      'signature': signature,
      'loan_days': ?loanDays,
      'condition_out': ?conditionOut,
      'notes': ?notes,
    };
    if (_sync != null) {
      return _sync.submit(SyncOp.libraryCheckout, payload);
    } else {
      final res = await _api.post('/library/circulation/checkout', body: payload, parse: asJson);
      return SyncOutcome.applied(res);
    }
  }

  Future<SyncOutcome> returnCopy(
    int loanId, {
    String? conditionIn,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'loan_id': loanId,
      'condition_in': ?conditionIn,
      'notes': ?notes,
    };
    if (_sync != null) {
      return _sync.submit(SyncOp.libraryReturn, payload);
    } else {
      final res = await _api.post('/library/circulation/return', body: payload, parse: asJson);
      return SyncOutcome.applied(res);
    }
  }

  // ---- librarian administration & dedicated book management ----
  Future<Paged<BookRequest>> requests({String? status, String? q, int page = 1}) =>
      _api.getPage('/library/requests', BookRequest.fromJson, page: page, query: {'status': status, 'q': q});
  Future<BookRequest> approve(int id, {String? note}) => _api.post('/library/requests/$id/approve', body: {'note': ?note}, parse: (d) => BookRequest.fromJson(asJson(d)));
  Future<BookRequest> reject(int id, String reason) => _api.post('/library/requests/$id/reject', body: {'reason': reason}, parse: (d) => BookRequest.fromJson(asJson(d)));
  Future<BookRequest> handOver(int id, {required String signature, int? loanDays}) =>
      _api.post('/library/requests/$id/issue', body: {'signature': signature, 'loan_days': ?loanDays}, parse: (d) => BookRequest.fromJson(asJson(d)));

  // Dedicated Digital Book management
  Future<Book> createDigitalBook(Json body) => _api.post('/library/digital-books', body: body, parse: (d) => Book.fromJson(asJson(d)));
  Future<Book> updateDigitalBook(int id, Json body) => _api.put('/library/digital-books/$id', body: body, parse: (d) => Book.fromJson(asJson(d)));
  Future<Book> uploadDigitalBookPdf(int id, String path) => _api.upload('/library/digital-books/$id/file', filePath: path, parse: (d) => Book.fromJson(asJson(d)));
  Future<Book> uploadDigitalBookCover(int id, String path) => _api.upload('/library/digital-books/$id/image', filePath: path, parse: (d) => Book.fromJson(asJson(d)));

  // Dedicated Physical Book management
  Future<Book> createPhysicalBook(Json body) => _api.post('/library/physical-books', body: body, parse: (d) => Book.fromJson(asJson(d)));
  Future<Book> updatePhysicalBook(int id, Json body) => _api.put('/library/physical-books/$id', body: body, parse: (d) => Book.fromJson(asJson(d)));
  Future<Book> uploadPhysicalBookCover(int id, String path) => _api.upload('/library/physical-books/$id/image', filePath: path, parse: (d) => Book.fromJson(asJson(d)));
  Future<void> deleteBook(int id) => _api.delete<void>('/library/books/$id');

  // Dedicated Physical Copies management
  Future<Paged<LibraryCopy>> getCopies({int? itemId, String? q, String? status, int page = 1}) =>
      _api.getPage(
        '/library/circulation/copies',
        LibraryCopy.fromJson,
        page: page,
        query: {
          if (itemId != null) 'item_id': itemId,
          if (q != null && q.isNotEmpty) 'q': q,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );

  Future<LibraryCopy> addCopy(int itemId, {String? condition, String? location}) =>
      _api.post(
        '/library/circulation/copies',
        body: {
          'item_id': itemId,
          if (condition != null) 'condition': condition,
          if (location != null) 'location': location,
        },
        parse: (d) => LibraryCopy.fromJson(asJson(d)),
      );

  Future<LibraryCopy> updateCopy(int copyId, {String? condition, String? location, String? status}) =>
      _api.put(
        '/library/circulation/copies/$copyId',
        body: {
          if (condition != null) 'condition': condition,
          if (location != null) 'location': location,
          if (status != null) 'status': status,
        },
        parse: (d) => LibraryCopy.fromJson(asJson(d)),
      );

  Future<void> deleteCopy(int copyId) =>
      _api.delete<void>('/library/circulation/copies/$copyId');

  Future<ItemModel> uploadBookPdf(int itemId, String path) => _api.upload('/items/$itemId/file', filePath: path, parse: (d) => ItemModel.fromJson(asJson(d)));
  Future<Json> uploadBookNarration(int itemId, String path) => _api.upload('/library/books/$itemId/narration', filePath: path, parse: asJson);

  // ---- student registration (registrar) ----
  Future<List<Json>> registrationClasses() => _api.get('/edu/registrations/classes', parse: asJsonList);
  Future<List<Json>> registeredStudents(int classId) => _api.get('/edu/registrations/classes/$classId/students', parse: asJsonList);
  Future<Json> register(Json body) => _api.post('/edu/registrations', body: body, parse: asJson);
  Future<List<Json>> unregister(int classId, int userId) => _api.delete('/edu/registrations/classes/$classId/students/$userId', parse: asJsonList);
}
