import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/edu/learn/edu_home.dart';
import 'package:mezmur_zelideta/features/edu/learn/grade_content_screen.dart';
import 'package:mezmur_zelideta/features/edu/learn/subject_grades_screen.dart';
import 'package:mezmur_zelideta/features/library/books_screen.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/models/library.dart';
import 'package:mezmur_zelideta/repositories/providers.dart';
import 'package:mezmur_zelideta/core/providers.dart';
import 'package:mezmur_zelideta/repositories/superapp_repositories.dart';
import 'package:mezmur_zelideta/services/book_vault.dart';
import 'package:mezmur_zelideta/services/favorites_service.dart';
import 'fakes.dart';

class _FakeBookFavoritesNotifier extends BookFavoritesController {
  @override
  Set<int> build() => const {};
  @override
  bool isFavorite(int id, [bool? fallback]) => fallback ?? false;
}

Future<({ApiClient api, SecureStore store})> _createApi(FakeAdapter adapter) async {
  FlutterSecureStorage.setMockInitialValues({
    'access_token': 'test_token',
    'refresh_token': 'refresh_token',
    'token_scope': 'app',
    'device_id': 'device_123',
  });
  final store = SecureStore();
  await store.load();
  final api = ApiClient(
    store,
    dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter,
  );
  return (api: api, store: store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Canonical Subjects Specification', () {
    test('canonicalSubjectsList has exactly 7 subjects in canonical order', () {
      expect(canonicalSubjectsList.length, 7);

      final expectedNames = [
        'ትምህርተ ሃይማኖት',
        'የመጽሐፍ ቅዱስ ጥናት',
        'ክርስቲያናዊ ሥነምግባር',
        'ሥርዓተ ቤተ ክርስቲያን',
        'የቤተክርስትያን ታሪክ',
        'ልሳነ ግእዝ',
        'ዜማ',
      ];

      for (var i = 0; i < 7; i++) {
        expect(canonicalSubjectsList[i].order, i + 1);
        expect(canonicalSubjectsList[i].name, expectedNames[i]);
      }
    });
  });

  group('2. Subject → Grade Selection Screen', () {
    testWidgets('Renders subject title and 12 grades from 1ኛ to 12ኛ ክፍል', (tester) async {
      final env = await _createApi(FakeAdapter((req) {
        if (req.path == '/edu/subjects/1/grades') {
          return (
            status: 200,
            body: ok({
              'subject': {
                'id': 1,
                'name': 'ትምህርተ ሃይማኖት',
                'description': 'የኦርቶዶክስ ተዋሕዶ ሃይማኖት መሠረተ እምነት',
              },
              'grades': List.generate(
                12,
                (i) => {
                  'grade_number': i + 1,
                  'grade_name': '${i + 1}ኛ ክፍል',
                  'grade_name_en': 'Grade ${i + 1}',
                  'courses_count': i == 5 ? 1 : 0,
                  'lessons_count': 0,
                  'materials_count': 0,
                  'quizzes_count': 0,
                  'has_content': i == 5,
                },
              ),
            }),
          );
        }
        return (status: 404, body: 'Not found');
      }));

      final eduRepo = EduRepository(env.api);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStoreProvider.overrideWithValue(env.store),
            apiClientProvider.overrideWithValue(env.api),
            eduRepositoryProvider.overrideWithValue(eduRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('am'), Locale('en')],
            locale: const Locale('am'),
            home: const EduSubjectGradesScreen(subjectId: 1),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Subject name and grade header
      expect(find.text('ትምህርተ ሃይማኖት'), findsOneWidget);
      expect(find.text('ክፍል ይምረጡ'), findsOneWidget);

      // Verify all 12 grades are displayed
      for (var i = 1; i <= 12; i++) {
        expect(find.text('$iኛ ክፍል'), findsOneWidget);
      }

      // Grade 6 has content pill
      expect(find.text('1 ይዘቶች'), findsOneWidget);
    });
  });

  group('3. Grade → Content Screen (Empty & Populated States)', () {
    testWidgets('Empty grade shows exact empty state message', (tester) async {
      final env = await _createApi(FakeAdapter((req) {
        if (req.path == '/edu/subjects/1/grades/1') {
          return (
            status: 200,
            body: ok({
              'subject': {'id': 1, 'name': 'ትምህርተ ሃይማኖት'},
              'grade': {'grade_number': 1, 'grade_name': '1ኛ ክፍል'},
              'courses': [],
              'lessons': [],
              'materials': [],
              'quizzes': [],
              'has_content': false,
              'can_manage': false,
            }),
          );
        }
        return (status: 404, body: 'Not found');
      }));

      final eduRepo = EduRepository(env.api);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStoreProvider.overrideWithValue(env.store),
            apiClientProvider.overrideWithValue(env.api),
            eduRepositoryProvider.overrideWithValue(eduRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('am'), Locale('en')],
            locale: const Locale('am'),
            home: const EduGradeContentScreen(subjectId: 1, gradeNumber: 1),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Subject and Grade title both identifiable
      expect(find.text('ትምህርተ ሃይማኖት — 1ኛ ክፍል'), findsOneWidget);

      // Mandatory empty state text
      expect(find.text('ለዚህ ክፍል እስካሁን የተጨመረ ይዘት የለም'), findsOneWidget);
    });

    testWidgets('Populated grade shows courses and lessons', (tester) async {
      final env = await _createApi(FakeAdapter((req) {
        if (req.path == '/edu/subjects/1/grades/6') {
          return (
            status: 200,
            body: ok({
              'subject': {'id': 1, 'name': 'ትምህርተ ሃይማኖት'},
              'grade': {'grade_number': 6, 'grade_name': '6ኛ ክፍል'},
              'courses': [
                {
                  'id': 7,
                  'name': 'ትምህርተ ሃይማኖት 6ኛ ክፍል',
                  'code': 'CRS-TH-06',
                  'instructor_name': 'መምህር ቀሲስ',
                }
              ],
              'lessons': [
                {
                  'id': 101,
                  'title': 'ምስጢረ ሥላሴ',
                  'est_minutes': 20,
                  'completed': false,
                  'opened': true,
                  'locked': false,
                }
              ],
              'materials': [
                {
                  'id': 201,
                  'title': 'የነገረ መለኮት ማጣቀሻ ጽሑፍ',
                  'kind': 'file',
                  'mime': 'application/pdf',
                  'size': 1048576,
                }
              ],
              'quizzes': [],
              'has_content': true,
              'can_manage': false,
            }),
          );
        }
        return (status: 404, body: 'Not found');
      }));

      final eduRepo = EduRepository(env.api);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStoreProvider.overrideWithValue(env.store),
            apiClientProvider.overrideWithValue(env.api),
            eduRepositoryProvider.overrideWithValue(eduRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('am'), Locale('en')],
            locale: const Locale('am'),
            home: const EduGradeContentScreen(subjectId: 1, gradeNumber: 6),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ትምህርተ ሃይማኖት — 6ኛ ክፍል'), findsOneWidget);
      expect(find.text('ትምህርተ ሃይማኖት 6ኛ ክፍል'), findsOneWidget);
      expect(find.text('ምስጢረ ሥላሴ'), findsOneWidget);
      expect(find.text('የነገረ መለኮት ማጣቀሻ ጽሑፍ'), findsOneWidget);
    });
  });

  group('4. Digital Books & Borrowing Safeguards', () {
    test('BookVault supports in-memory fallback on web without errors', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      await BookVault.save(999, bytes);
      final has = await BookVault.has(999);
      expect(has, true);

      final readBytes = await BookVault.read(999);
      expect(readBytes, bytes);

      await BookVault.remove(999);
      final hasAfterRemove = await BookVault.has(999);
      expect(hasAfterRemove, false);
    });

    testWidgets('BookCard displays Borrowed pill for active loans', (tester) async {
      final activeLoanBook = Book(
        id: 25,
        title: 'መጽሓፍ 2',
        code: 'BK-0025',
        kind: 'physical',
        available: 0,
        quantity: 2,
        copiesAvailable: 0,
        copiesTotal: 2,
        myRequest: 'issued', // Active borrowing
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookFavoritesProvider.overrideWith(_FakeBookFavoritesNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('am'), Locale('en')],
            locale: const Locale('am'),
            home: Scaffold(
              body: BookCard(
                book: activeLoanBook,
                onChanged: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Displays Borrowed ("ተወስዷል") status pill
      expect(find.text('ተወስዷል'), findsOneWidget);

      // Does NOT show request button
      expect(find.byKey(const ValueKey('book-request-25')), findsNothing);
    });

    testWidgets('Digital book without file shows File not uploaded pill', (tester) async {
      const digitalNoFileBook = Book(
        id: 22,
        title: 'መሰረተ',
        code: 'BK-0022',
        kind: 'digital',
        fileUrl: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookFavoritesProvider.overrideWith(_FakeBookFavoritesNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('am'), Locale('en')],
            locale: const Locale('am'),
            home: Scaffold(
              body: BookCard(
                book: digitalNoFileBook,
                onChanged: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Displays "ፋይል አልተጫነም"
      expect(find.text('ፋይል አልተጫነም'), findsOneWidget);
    });
  });
}
