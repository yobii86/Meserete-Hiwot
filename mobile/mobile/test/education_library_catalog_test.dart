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
import 'package:mezmur_zelideta/features/edu/admin/edu_book_catalog_screen.dart';
import 'package:mezmur_zelideta/features/library/books_screen.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/repositories/library_repository.dart';
import 'package:mezmur_zelideta/repositories/providers.dart';

import 'fakes.dart';

Future<ApiClient> _createApi(FakeAdapter adapter) async {
  FlutterSecureStorage.setMockInitialValues({'access_token': 't', 'refresh_token': 'r', 'token_scope': 'app', 'device_id': 'd'});
  final store = SecureStore();
  await store.load();
  return ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Education Library & Admin Catalog Architecture', () {
    testWidgets('LibraryBooksScreen displays category browsing chips and filters books', (tester) async {
      final api = await _createApi(FakeAdapter((req) {
        if (req.path == '/library/categories') {
          return (
            status: 200,
            body: {
              'success': true,
              'code': 'OK',
              'message': 'OK',
              'data': [
                {
                  'id': 10,
                  'name': 'ትምህርተ ሃይማኖት',
                  'name_en': 'Theology',
                  'code': 'THEO',
                  'books_count': 5,
                },
                {
                  'id': 20,
                  'name': 'መጽሐፍ ቅዱስ ጥናት',
                  'name_en': 'Biblical Studies',
                  'code': 'BIBLE',
                  'books_count': 3,
                },
              ],
              'errors': [],
            },
          );
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
                  'title': 'ሃይማኖተ አበው',
                  'author': 'ሊቃውንተ ቤተክርስቲያን',
                  'code': 'BK-0001',
                  'kind': 'digital',
                  'category_id': 10,
                  'category_name': 'ትምህርተ ሃይማኖት',
                  'is_favorite': false,
                },
                {
                  'id': 2,
                  'title': 'ያልተመደበ አጠቃላይ መጽሐፍ',
                  'author': 'ጸሐፊ',
                  'code': 'BK-0002',
                  'kind': 'physical',
                  'category_id': null,
                  'category_name': null,
                  'is_favorite': false,
                  'available': 2,
                  'quantity': 2,
                },
              ],
              'meta': {'page': 1, 'pages': 1, 'total': 2},
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
            home: const LibraryBooksScreen(domain: 'timhirt'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify category browser bar chips rendered
      expect(find.text('All Categories'), findsOneWidget);
      expect(find.text('ትምህርተ ሃይማኖት'), findsAtLeastNWidgets(1));
      expect(find.text('መጽሐፍ ቅዱስ ጥናት'), findsOneWidget);
      expect(find.text('Unclassified'), findsAtLeastNWidgets(1));

      // Verify book cards display category and format pills
      expect(find.text('ሃይማኖተ አበው'), findsAtLeastNWidgets(1));
      expect(find.text('ያልተመደበ አጠቃላይ መጽሐፍ'), findsAtLeastNWidgets(1));
      expect(find.text('PDF'), findsAtLeastNWidgets(1));
    });

    testWidgets('EduBookCatalogScreen renders administrative controls and options', (tester) async {
      final api = await _createApi(FakeAdapter((req) {
        if (req.path == '/library/categories') {
          return (
            status: 200,
            body: {
              'success': true,
              'code': 'OK',
              'message': 'OK',
              'data': [
                {
                  'id': 10,
                  'name': 'ትምህርተ ሃይማኖት',
                  'code': 'THEO',
                  'books_count': 1,
                },
              ],
              'errors': [],
            },
          );
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
                  'id': 101,
                  'title': 'የሰንበት ትምህርት ቤት መማሪያ',
                  'author': 'መጋቤ ሐዲስ',
                  'code': 'EDU-BK-0101',
                  'kind': 'digital',
                  'category_id': 10,
                  'category_name': 'ትምህርተ ሃይማኖት',
                  'status': 'active',
                  'downloads': 15,
                  'file_url': '/library/books/101/file',
                  'file_size': 2048576,
                },
                {
                  'id': 102,
                  'title': 'የታተመ የኪዳን ጸሎት',
                  'author': 'መምህር',
                  'code': 'LIB-LIT-0002',
                  'kind': 'physical',
                  'category_id': null,
                  'status': 'active',
                  'available': 3,
                  'quantity': 5,
                  'copies_available': 3,
                  'copies_total': 5,
                  'location': 'Shelf C-1',
                },
              ],
              'meta': {'page': 1, 'pages': 1, 'total': 2},
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
            home: const EduBookCatalogScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify admin catalog screen headers and action buttons
      expect(find.text('Book Catalog Administration'), findsOneWidget);
      expect(find.text('+ Digital Book'), findsOneWidget);
      expect(find.text('+ Physical Book'), findsOneWidget);

      // Verify admin cards content
      expect(find.text('የሰንበት ትምህርት ቤት መማሪያ'), findsAtLeastNWidgets(1));
      expect(find.text('የታተመ የኪዳን ጸሎት'), findsAtLeastNWidgets(1));
      expect(find.text('Edit'), findsAtLeastNWidgets(2));
      expect(find.text('Replace PDF'), findsOneWidget);
      expect(find.text('Copies'), findsOneWidget);
    });
  });
}

