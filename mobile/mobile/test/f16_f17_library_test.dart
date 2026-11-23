import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/providers.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/features/library/book_cover.dart';
import 'package:mezmur_zelideta/features/library/book_detail_screen.dart';
import 'package:mezmur_zelideta/features/library/books_screen.dart';
import 'package:mezmur_zelideta/features/library/circulation_screen.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/models/library.dart';
import 'package:mezmur_zelideta/repositories/library_repository.dart';
import 'package:mezmur_zelideta/repositories/providers.dart';
import 'package:mezmur_zelideta/services/narration_player_service.dart';

import 'fakes.dart';

Future<ApiClient> _createApi(FakeAdapter adapter) async {
  FlutterSecureStorage.setMockInitialValues({'access_token': 't', 'refresh_token': 'r', 'token_scope': 'app', 'device_id': 'd'});
  final store = SecureStore();
  await store.load();
  return ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F16 & F17 Models', () {
    test('Book model parses progress, favorites, copies, and narration', () {
      final json = {
        'id': 42,
        'title': 'የነገረ መለኮት መግቢያ',
        'author': 'መጋቤ ሐዲስ ዶ/ር ሮዳስ ታደሰ',
        'code': 'BK-0042',
        'kind': 'digital',
        'category': 'ነገረ መለኮት',
        'category_id': 3,
        'category_name': 'ነገረ መለኮት',
        'file_url': '/library/books/42/file',
        'file_size': 10485760,
        'narration_url': '/library/books/42/narration',
        'narration_mime': 'audio/mpeg',
        'narration_duration': 3600,
        'is_favorite': true,
        'progress': {
          'page': 14,
          'page_count': 120,
          'audio_position_ms': 75000,
          'updated_at': '2026-10-16T10:00:00Z',
        },
        'copies_available': 5,
        'copies_total': 8,
      };

      final book = Book.fromJson(json);
      expect(book.id, 42);
      expect(book.title, 'የነገረ መለኮት መግቢያ');
      expect(book.isDigital, true);
      expect(book.isFavorite, true);
      expect(book.hasNarration, true);
      expect(book.narrationDuration, 3600);
      expect(book.progress?.page, 14);
      expect(book.progress?.pageCount, 120);
      expect(book.progress?.audioPositionMs, 75000);
      expect(book.effectiveAvailable, 5);
      expect(book.effectiveTotal, 8);
    });

    test('LibraryCategory parses hierarchy with children', () {
      final json = {
        'id': 1,
        'name': 'ትምህርት',
        'name_en': 'Education',
        'code': 'EDU',
        'children': [
          {
            'id': 2,
            'parent_id': 1,
            'name': 'ነገረ ሃይማኖት',
            'name_en': 'Theology',
            'code': 'THEO',
            'books_count': 15,
            'children': [],
          }
        ],
      };

      final cat = LibraryCategory.fromJson(json);
      expect(cat.id, 1);
      expect(cat.name, 'ትምህርት');
      expect(cat.children.length, 1);
      expect(cat.children.first.id, 2);
      expect(cat.children.first.parentId, 1);
      expect(cat.children.first.booksCount, 15);
    });

    test('LibraryCopy and LibraryLoan parse correctly', () {
      final copyJson = {
        'id': 10,
        'item_id': 42,
        'copy_no': 2,
        'copy_code': 'LIB-THEO-0042-02',
        'condition': 'good',
        'status': 'available',
        'book_title': 'የነገረ መለኮት መግቢያ',
      };
      final copy = LibraryCopy.fromJson(copyJson);
      expect(copy.id, 10);
      expect(copy.copyCode, 'LIB-THEO-0042-02');
      expect(copy.isAvailable, true);
      expect(copy.isOnLoan, false);

      final loanJson = {
        'id': 55,
        'copy_id': 10,
        'copy_code': 'LIB-THEO-0042-02',
        'book_id': 42,
        'book_title': 'የነገረ መለኮት መግቢያ',
        'user_id': 100,
        'borrower_name': 'ዮሐንስ ተስፋዬ',
        'checked_out_at': '2026-10-01T08:00:00Z',
        'due_on': '2026-10-15',
        'condition_out': 'good',
        'status': 'active',
      };
      final loan = LibraryLoan.fromJson(loanJson);
      expect(loan.id, 55);
      expect(loan.copyCode, 'LIB-THEO-0042-02');
      expect(loan.borrowerName, 'ዮሐንስ ተስፋዬ');
      expect(loan.isActive, true);
      expect(loan.isOverdue, true); // Oct 15 is before current Oct 16
    });
  });

  group('LibraryRepository Endpoints', () {
    test('fetches categories and toggles favorite', () async {
      final api = await _createApi(FakeAdapter((req) {
        if (req.path == '/library/categories') {
          return (
            status: 200,
            body: ok([
              {'id': 1, 'name': 'መጽሐፍ ቅዱስ', 'code': 'BIB', 'books_count': 5},
              {'id': 2, 'name': 'ነገረ ሃይማኖት', 'code': 'THEO', 'books_count': 8},
            ]),
          );
        }
        if (req.path == '/library/books/42/favorite') {
          return (status: 200, body: ok({'favorited': true}));
        }
        return (status: 404, body: 'Not found');
      }));

      final repo = LibraryRepository(api);
      final cats = await repo.categories();
      expect(cats.length, 2);
      expect(cats.first.code, 'BIB');

      final fav = await repo.toggleFavorite(42);
      expect(fav, true);
    });

    test('finds copy by code, checks out and returns', () async {
      final api = await _createApi(FakeAdapter((req) {
        if (req.path == '/library/circulation/copies/by-code/LIB-THEO-0042-01') {
          return (
            status: 200,
            body: ok({
              'id': 1,
              'item_id': 42,
              'copy_no': 1,
              'copy_code': 'LIB-THEO-0042-01',
              'condition': 'good',
              'status': 'available',
              'book_title': 'የነገረ መለኮት መግቢያ',
            }),
          );
        }
        if (req.path == '/library/circulation/checkout') {
          expect(req.data['copy_id'], 1);
          expect(req.data['user_id'], 100);
          expect(req.data['signature'], 'data:image/png;base64,mock');
          return (
            status: 200,
            body: ok({
              'id': 77,
              'copy_id': 1,
              'user_id': 100,
              'status': 'active',
              'due_on': '2026-10-30',
            }),
          );
        }
        if (req.path == '/library/circulation/return') {
          expect(req.data['loan_id'], 77);
          expect(req.data['condition_in'], 'good');
          return (
            status: 200,
            body: ok({
              'id': 77,
              'status': 'returned',
              'condition_in': 'good',
            }),
          );
        }
        return (status: 404, body: 'Not found');
      }));

      final repo = LibraryRepository(api);
      final copy = await repo.findCopyByCode('LIB-THEO-0042-01');
      expect(copy.id, 1);
      expect(copy.isAvailable, true);

      final checkoutOutcome = await repo.checkout(
        copyId: 1,
        userId: 100,
        signature: 'data:image/png;base64,mock',
      );
      expect(checkoutOutcome.applied, true);

      final returnOutcome = await repo.returnCopy(77, conditionIn: 'good');
      expect(returnOutcome.applied, true);
    });
  });

  group('NarrationPlayerState', () {
    test('handles playback state transitions correctly', () {
      const state = NarrationPlayerState();
      expect(state.isPlaying, false);
      expect(state.hasNarration, false);

      const b = Book(
        id: 1,
        title: 'መጽሐፈ ቅዳሴ',
        code: 'BK-0001',
        narrationUrl: '/stream',
        narrationDuration: 1800,
      );

      final active = state.copyWith(
        book: () => b,
        isPlaying: true,
        duration: const Duration(seconds: 1800),
        position: const Duration(seconds: 120),
      );

      expect(active.hasNarration, true);
      expect(active.isPlaying, true);
      expect(active.duration.inSeconds, 1800);
      expect(active.position.inSeconds, 120);
    });
  });

  group('Library UI Screens', () {
    testWidgets('LibraryBooksScreen renders tabs and category filter', (tester) async {
      final api = await _createApi(FakeAdapter((req) {
        if (req.path == '/library/categories') {
          return (status: 200, body: ok([]));
        }
        if (req.path == '/library/books') {
          return (
            status: 200,
            body: {
              'success': true,
              'code': 'OK',
              'message': 'OK',
              'data': [
                {
                  'id': 1,
                  'title': 'መጽሐፈ ቅዳሴ ትርጓሜ',
                  'code': 'BK-0001',
                  'kind': 'digital',
                  'is_favorite': false,
                }
              ],
              'meta': {'page': 1, 'pages': 1, 'total': 1},
              'errors': [],
            },
          );
        }
        return (status: 404, body: 'Not found');
      }));

      final repo = LibraryRepository(api);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            apiClientProvider.overrideWithValue(api),
            libraryRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            locale: const Locale('en'),
            home: const LibraryBooksScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Digital books'), findsOneWidget);
      expect(find.text('Books to borrow'), findsOneWidget);
      expect(find.text('Mine'), findsOneWidget);
      expect(find.byKey(const ValueKey('library-shortcut-discover')), findsOneWidget);
      expect(find.byKey(const ValueKey('library-shortcut-favorites')), findsOneWidget);
      expect(find.text('መጽሐፈ ቅዳሴ ትርጓሜ'), findsAtLeastNWidgets(1));
    });

    testWidgets('LibraryCirculationScreen renders tabs and checkout elements', (tester) async {
      final api = await _createApi(FakeAdapter((req) {
        return (
          status: 200,
          body: {
            'success': true,
            'code': 'OK',
            'message': 'OK',
            'data': [],
            'meta': {'page': 1, 'pages': 1, 'total': 0},
            'errors': [],
          },
        );
      }));
      final repo = LibraryRepository(api);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            apiClientProvider.overrideWithValue(api),
            libraryRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            locale: const Locale('en'),
            home: const LibraryCirculationScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Check out'), findsWidgets);
      expect(find.text('Active loans'), findsOneWidget);
      expect(find.text('Copies'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.byKey(const ValueKey('checkout-copy-code-input')), findsOneWidget);
      expect(find.byKey(const ValueKey('checkout-select-borrower-btn')), findsOneWidget);
    });

    testWidgets('BookCover renders liturgical fallback with cross, title, and author when cover is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: BookCover(
              title: 'መጽሐፈ ቅዳሴ ትርጓሜ',
              author: 'መጋቤ ሐዲስ',
              category: 'ስነ መለኮት',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('መጽሐፈ ቅዳሴ ትርጓሜ'), findsOneWidget);
      expect(find.text('መጋቤ ሐዲስ'), findsOneWidget);
      expect(find.byIcon(Icons.church_rounded), findsOneWidget);
    });

    testWidgets('BookDetailScreen renders book details, metrics grid, and primary action', (tester) async {
      final book = const Book(
        id: 99,
        title: 'የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተ ክርስቲያን ታሪክ',
        author: 'ብፁዕ አቡነ ጎርጎርዮስ',
        code: 'BK-0099',
        kind: 'digital',
        category: 'ታሪክ',
        fileUrl: '/library/books/99/file',
        fileSize: 4194304,
        description: 'የቤተ ክርስቲያናችን ጥንታዊ ታሪክ',
      );

      final api = await _createApi(FakeAdapter((req) {
        if (req.path == '/library/books/99') {
          return (
            status: 200,
            body: {
              'success': true,
              'code': 'OK',
              'message': 'OK',
              'data': book.toJson()..['id'] = 99..['title'] = book.title..['author'] = book.author,
              'errors': [],
            },
          );
        }
        return (status: 404, body: 'Not found');
      }));

      final repo = LibraryRepository(api);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            apiClientProvider.overrideWithValue(api),
            libraryRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            locale: const Locale('en'),
            home: BookDetailScreen(book: book),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Book Details'), findsOneWidget);
      expect(find.text('የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተ ክርስቲያን ታሪክ'), findsAtLeastNWidgets(1));
      expect(find.text('ብፁዕ አቡነ ጎርጎርዮስ'), findsAtLeastNWidgets(1));
      expect(find.text('Format'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('About This Book'), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-action-99')), findsOneWidget);
    });

    testWidgets('LibraryBooksScreen switches between category shortcuts (Discover, Favorites, Downloads, Reading)', (tester) async {
      final api = await _createApi(FakeAdapter((req) {
        if (req.path == '/library/categories') {
          return (status: 200, body: ok([]));
        }
        if (req.path == '/library/books') {
          return (
            status: 200,
            body: {
              'success': true,
              'code': 'OK',
              'message': 'OK',
              'data': [],
              'meta': {'page': 1, 'pages': 1, 'total': 0},
              'errors': [],
            },
          );
        }
        return (status: 404, body: 'Not found');
      }));

      final repo = LibraryRepository(api);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            apiClientProvider.overrideWithValue(api),
            libraryRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            locale: const Locale('en'),
            home: const LibraryBooksScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Favorites shortcut
      await tester.tap(find.byKey(const ValueKey('library-shortcut-favorites')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('favorites-shelf-list')), findsOneWidget);

      // Tap Downloads shortcut
      await tester.tap(find.byKey(const ValueKey('library-shortcut-downloads')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('downloads-shelf-list')), findsOneWidget);

      // Tap Reading shortcut
      await tester.tap(find.byKey(const ValueKey('library-shortcut-reading')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reading-shelf-list')), findsOneWidget);

      // Tap Discover shortcut
      await tester.tap(find.byKey(const ValueKey('library-shortcut-discover')));
      await tester.pumpAndSettle();
      expect(find.text('Explore Books'), findsOneWidget);
    });
  });
}
