import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/app/deep_links.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/features/edu/edu_screens.dart';
import 'package:mezmur_zelideta/features/edu/learn/edu_home.dart';
import 'package:mezmur_zelideta/features/edu/learn/edu_widgets.dart';
import 'package:mezmur_zelideta/features/edu/learn/learn_screens.dart';
import 'package:mezmur_zelideta/features/edu/learn/progress_more.dart';
import 'package:mezmur_zelideta/features/edu/learn/quiz_screens.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/repositories/providers.dart';
import 'package:mezmur_zelideta/repositories/superapp_repositories.dart';

import 'fakes.dart';

Future<ApiClient> _api(FakeAdapter adapter) async {
  FlutterSecureStorage.setMockInitialValues({'access_token': 't', 'refresh_token': 'r', 'token_scope': 'app', 'device_id': 'd'});
  final store = SecureStore();
  await store.load();
  return ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
}

class _SignedOutSession extends SessionController {
  @override
  SessionState build() => const SignedOut();
}

Widget _app(Widget child, ApiClient api) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        sessionProvider.overrideWith(_SignedOutSession.new),
        eduRepositoryProvider.overrideWithValue(EduRepository(api)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        home: child,
      ),
    );

Map<String, dynamic> _category(int id, String am, String en, int lessons) => {'id': id, 'name': am, 'name_en': en, 'icon_key': 'bible', 'status': 'active', 'lesson_count': lessons, 'subject_count': 1};

final _categories = [
  _category(1, 'ትምህርተ ሃይማኖት', 'Theology & Doctrine', 12),
  _category(4, 'የመጽሐፍ ቅዱስ ጥናት', 'Bible Study', 12),
  _category(5, 'ክርስቲያናዊ ሥነምግባር', 'Christian Ethics', 12),
  _category(6, 'ሥርዓተ ቤተ ክርስቲያን', 'Church Order & Rites', 12),
  _category(3, 'የቤተክርስትያን ታሪክ', 'Church History', 12),
  _category(7, 'ልሳነ ግእዝ', 'Geez Language', 12),
  _category(8, 'ዜማ', 'Zema (Sacred Chants)', 12),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('lesson text (simple formatting, no HTML)', () {
    test('headings, quotes, list items and paragraphs', () {
      final b = parseLessonBody('# Title\n\nFirst line\ncontinues here.\n\n> Acts 2:1\n- one\n- two\n\n## Sub\nLast');
      expect(b.map((x) => x.type).toList(), [
        LessonBlockType.heading,
        LessonBlockType.paragraph,
        LessonBlockType.quote,
        LessonBlockType.bullet,
        LessonBlockType.bullet,
        LessonBlockType.subheading,
        LessonBlockType.paragraph,
      ]);
      expect(b[1].text, 'First line continues here.');
      expect(b[2].text, 'Acts 2:1');
    });

    test('markup-looking text stays plain text', () {
      final b = parseLessonBody('<script>alert(1)</script>');
      expect(b.single.type, LessonBlockType.paragraph);
      expect(b.single.text, '<script>alert(1)</script>');
      expect(parseLessonBody(null), isEmpty);
      expect(parseLessonBody('   \n  '), isEmpty);
    });
  });

  test('notifications about lessons, quizzes, materials, results and attempts open them', () {
    expect(routeForEntity('edu_lesson', 7), '/edu/learn/lesson/7');
    expect(routeForEntity('edu_quiz', 3), '/edu/quiz/3');
    expect(routeForEntity('edu_quiz', 3, data: {'attempt_id': 10}), '/edu/attempt/10');
    expect(routeForEntity('edu_grading', 3, data: {'attempt_id': 10}), '/edu/attempt/10');
    expect(routeForEntity('edu_material', 5, data: {'lesson_id': 7}), '/edu/learn/lesson/7');
    expect(routeForEntity('edu_course', 5), '/edu/course/5?tab=assessments');
    expect(routeForEntity('edu_assessment', 9), '/edu/review/assessment/9');
    expect(routeForEntity('edu_class', 2), '/edu/classes');
    // Sanitize removed routes
    expect(routeForEntity(null, null, data: {'route': '/edu/calendar'}), '/edu');
    expect(routeForEntity(null, null, data: {'route': '/edu/content/units-lessons'}), '/edu/content');
  });

  group('ትምህርት home', () {
    testWidgets('an enrolled student sees the banner, categories, this week and the real progress', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final api = await _api(FakeAdapter((req) => (status: 200, body: ok({
            'featured': [
              {'id': 1, 'target_type': 'lesson', 'target_id': 4, 'title': 'Theology — Foundations of Faith', 'subtitle': null, 'image_url': null, 'is_active': true,
                'target': {'route': '/edu/learn/lesson/4', 'position': 1, 'total': 12}},
            ],
            'categories': _categories,
            'continue': {'lesson_id': 4, 'lesson_title': 'The Apostolic Church', 'subject_id': 2, 'subject_name': 'የቤተ ክርስቲያን ታሪክ', 'subject_name_en': 'Church History', 'position': 1, 'total': 10,
              'progress': {'completed': 4, 'total': 10, 'percent': 40}},
            'classes': [{'id': 1, 'name': '7ኛ', 'my_program': 'regular'}],
            'next_sessions': [],
            'open_registration': 0,
            'student': {
              'assignments_due': [{'id': 3, 'title': 'Essay on Nicaea', 'due_at': '2026-10-20T10:00:00.000Z', 'course_name': 'History', 'class_id': 1, 'overdue': false}],
              'quizzes': [{'id': 8, 'title': 'Week 3 quiz', 'course_name': 'History', 'availability': 'open', 'attempts_left': 1, 'max_attempts': 1}],
              'attendance': [{'class_id': 1, 'class_name': '7ኛ', 'rate': 80, 'total': 5}],
              'results': [],
            },
            'teaching': null,
            'attendance_classes': [],
            'admin': null,
            'roles': {'student': true},
          }))));
      await tester.pumpWidget(_app(const EduHomeScreen(), api));
      await tester.pumpAndSettle();

      expect(find.text('Theology — Foundations of Faith'), findsOneWidget);
      expect(find.text('Lesson 1 of 12'), findsOneWidget);
      expect(find.text('The Apostolic Church'), findsOneWidget);
      expect(find.text('40% completed'), findsOneWidget);
      expect(find.text('Weekly quizzes'), findsOneWidget);
      expect(find.text('Essay on Nicaea'), findsOneWidget);
      expect(find.text('Education administration'), findsNothing);

      // Full curriculum categories are housed in the dedicated Class destination
      await tester.pumpWidget(_app(const EduClassesScreen(), api));
      await tester.pumpAndSettle();
      for (final c in [
        'ትምህርተ ሃይማኖት',
        'የመጽሐፍ ቅዱስ ጥናት',
        'ክርስቲያናዊ ሥነምግባር',
        'ሥርዓተ ቤተ ክርስቲያን',
        'የቤተክርስትያን ታሪክ',
        'ልሳነ ግእዝ',
        'ዜማ',
      ]) {
        expect(find.text(c), findsWidgets);
      }
      expect(find.text('12 Grades'), findsWidgets);
    });

    testWidgets('a new member is guided to registration, without quizzes or fake numbers', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final api = await _api(FakeAdapter((req) => (status: 200, body: ok({
            'featured': [],
            'categories': _categories,
            'continue': null,
            'classes': [],
            'next_sessions': [],
            'open_registration': 2,
            'student': null,
            'teaching': null,
            'attendance_classes': [],
            'admin': null,
            'roles': {'student': false},
          }))));
      await tester.pumpWidget(_app(const EduHomeScreen(), api));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('You are not enrolled in a class yet'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('You are not enrolled in a class yet. 2 class(es)'), findsOneWidget);
      expect(find.text('Weekly quizzes'), findsNothing);
      expect(find.text('Continue learning'), findsNothing);
      expect(find.byType(FeaturedCarousel), findsNothing);

      // Verify Class destination also houses categories
      await tester.pumpWidget(_app(const EduClassesScreen(), api));
      await tester.pumpAndSettle();
      expect(find.text('ትምህርተ ሃይማኖት'), findsWidgets);
    });
  });

  testWidgets('the home fits a 360 dp phone with large system text (no overflow)', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 3000 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final api = await _api(FakeAdapter((req) => (status: 200, body: ok({
          'featured': [
            {'id': 1, 'target_type': 'subject', 'target_id': 2, 'title': 'A rather long featured subject title that wraps', 'subtitle': 'Church History of the Ethiopian Orthodox Tewahedo Church', 'image_url': null, 'is_active': true,
              'target': {'route': '/edu/learn/subject/2', 'progress': {'completed': 3, 'total': 12}}},
          ],
          'categories': _categories,
          'continue': {'lesson_id': 4, 'lesson_title': 'A long lesson title about the Ecumenical Councils', 'subject_name': 'የቤተ ክርስቲያን ታሪክ', 'subject_name_en': 'Church History', 'progress': {'completed': 4, 'total': 10}},
          'classes': [{'id': 1, 'name': '7ኛ', 'my_program': 'regular'}],
          'next_sessions': [{'date': '2026-10-18', 'class_id': 1, 'class_name': '7ኛ', 'course_name': 'History', 'starts': '08:00', 'ends': '10:00', 'location': 'Hall'}],
          'open_registration': 0,
          'student': {
            'assignments_due': [{'id': 3, 'title': 'Essay', 'due_at': '2026-10-20T10:00:00.000Z', 'course_name': 'History', 'class_id': 1, 'overdue': true}],
            'quizzes': [
              {'id': 8, 'title': 'Week 3 quiz', 'course_name': 'History', 'availability': 'open', 'attempts_left': 1},
              {'id': 9, 'title': 'Week 4 quiz', 'course_name': 'History', 'availability': 'open', 'attempts_left': 1, 'closes_at': '2026-10-25T10:00:00.000Z', 'official': true},
            ],
            'attendance': [{'class_id': 1, 'class_name': '7ኛ', 'rate': 80, 'total': 5}],
            'results': [{'assessment_id': 1, 'title': 'Mid exam', 'score': 40, 'max_score': 50, 'course_name': 'History', 'class_id': 1}],
          },
          'teaching': {'courses': [{'id': 5, 'name': 'Church History', 'class_name': '7ኛ', 'student_count': 30}], 'submissions_to_grade': 3, 'marks_rejected': 1, 'marks_draft': 0, 'quiz_answers_to_grade': 2},
          'attendance_classes': [],
          'admin': {'marks_submitted': 2, 'marks_approved_unpublished': 1, 'requests_pending': 4, 'complaints_open': 1, 'subjects_unlinked': 6},
          'roles': {'student': true, 'teacher': true, 'admin': true},
        }))));
    await tester.pumpWidget(_app(const EduHomeScreen(), api));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('education.home.learn.shortcut')), findsNothing);
    expect(find.byKey(const ValueKey('education.home.books.shortcut')), findsNothing);
  });

  group('screens fit a 360 dp phone with large system text', () {
    final responses = <String, Object>{
      '/edu/subjects/2': {
        'id': 2, 'name': 'የቤተ ክርስቲያን ታሪክ', 'name_en': 'Church History', 'description': 'From the apostles to the councils.', 'objectives': 'Know the councils.',
        'status': 'published', 'visibility': 'enrolled', 'sequential': true, 'can_open': true, 'can_edit': false, 'enrolled': true,
        'my_progress': {'completed': 1, 'total': 3, 'percent': 33},
        'units': [
          {'id': 1, 'title': 'Chapter 1: Origin of the Church', 'lessons': [
            {'id': 4, 'title': 'Lesson 1: The Apostolic Church', 'status': 'published', 'completed': true, 'est_minutes': 15},
            {'id': 5, 'title': 'Lesson 2: Persecution and Martyrdom', 'status': 'published', 'opened': true, 'est_minutes': 20, 'material_count': 2},
            {'id': 6, 'title': 'Lesson 3: Ecumenical Councils', 'status': 'published', 'locked': true},
          ]},
        ],
        'lessons': [],
      },
      '/edu/lessons/5': {
        'id': 5, 'title': '1.1 The Foundation of the Church', 'summary': 'How the Church began', 'status': 'published',
        'body': '# The Church\n\nThe holy Church was founded by our Lord in His blood, on the faith of the apostles.\n\n> Matthew 16:18\n\n- Pentecost\n- The apostles',
        'scripture_refs': 'Matt 16:18; Acts 2', 'objectives': 'Explain how the Church began.',
        'unit': {'id': 1, 'title': 'Chapter 1'}, 'subject': {'id': 2, 'name': 'የቤተ ክርስቲያን ታሪክ', 'name_en': 'Church History'},
        'position': 2, 'total': 3, 'prev_id': 4, 'next_id': 6, 'completed': false, 'bookmarked': true, 'can_edit': false,
        'materials': [
          {'id': 1, 'kind': 'file', 'title': 'Lesson notes (PDF)', 'name': 'notes.pdf', 'mime': 'application/pdf', 'size': 240000},
          {'id': 2, 'kind': 'file', 'title': 'Narration', 'name': 'narration.mp3', 'mime': 'audio/mpeg', 'size': 3400000},
          {'id': 3, 'kind': 'video_link', 'title': 'Video', 'url': 'https://youtu.be/x'},
        ],
        'quizzes': [{'id': 8, 'title': 'Week 3 quiz'}],
      },
      '/edu/attempts/11': {
        'id': 11, 'quiz_id': 8, 'attempt_no': 1, 'status': 'in_progress', 'seconds_left': 600, 'max_score': 3,
        'quiz': {'id': 8, 'title': 'Weekly quiz', 'review_policy': 'practice', 'official': false},
        'questions': [
          {'id': 1, 'type': 'single', 'prompt': 'Where was the first Church council held?', 'points': 1, 'options': [
            {'id': 'a', 'text': 'Jerusalem'}, {'id': 'b', 'text': 'Antioch'}, {'id': 'c', 'text': 'Rome'}, {'id': 'd', 'text': 'Alexandria'}]},
          {'id': 2, 'type': 'true_false', 'prompt': 'Nicaea was in 325', 'points': 1},
        ],
      },
      '/edu/quizzes/8': {
        'id': 8, 'title': 'Week 3 quiz with a long title', 'course_name': 'History', 'class_name': '7ኛ', 'availability': 'open', 'attempts_left': 1, 'attempts_used': 0, 'max_attempts': 1,
        'question_count': 4, 'time_limit_minutes': 10, 'closes_at': '2026-10-25T10:00:00.000Z', 'review_policy': 'after_close', 'official': true, 'instructions': 'Answer all questions.',
      },
      '/edu/me/quizzes': [
        {'id': 8, 'title': 'Week 3 quiz with a long title', 'course_name': 'History', 'class_name': '7ኛ', 'availability': 'open', 'attempts_left': 1, 'attempts_used': 0, 'max_attempts': 1,
          'question_count': 4, 'time_limit_minutes': 10, 'closes_at': '2026-10-25T10:00:00.000Z', 'review_policy': 'after_close', 'official': true, 'instructions': 'Answer all questions.'},
      ],
      '/edu/me/progress': {
        'subjects': [{'id': 2, 'name': 'የቤተ ክርስቲያን ታሪክ', 'name_en': 'Church History', 'progress': {'completed': 1, 'total': 3}, 'enrolled': true}],
        'classes': [{'class': {'id': 1, 'name': '7ኛ'}, 'attendance': {'rate': 80, 'present': 3, 'late': 1, 'absent': 1, 'excused': 0, 'total': 5},
          'courses': [{'course': {'id': 5, 'name': 'Church History'}, 'total_percent': 82.5}, {'course': {'id': 6, 'name': "Ge'ez"}, 'total_percent': null}]}],
        'quizzes': [{'id': 8, 'title': 'Week 3 quiz', 'course_name': 'History', 'availability': 'closed', 'attempts_used': 1, 'my_score': 3, 'my_max_score': 4}],
        'bookmarks': [{'lesson_id': 5, 'title': 'The Foundation of the Church', 'subject_name': 'Church History', 'completed': false}],
      },
    };

    Future<void> pump(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(360 * 3, 1800 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = await _api(FakeAdapter((req) {
        final path = req.path.replaceFirst('http://test/api/v1', '');
        final r = responses[path];
        return r == null ? (status: 404, body: failBody('NOT_FOUND')) : (status: 200, body: ok(r));
      }));
      await tester.pumpWidget(_app(screen, api));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }

    testWidgets('subject with units and lessons', (tester) async {
      await pump(tester, const EduSubjectScreen(subjectId: 2));
      expect(find.text('Lesson 2: Persecution and Martyrdom'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
    });

    testWidgets('lesson reader', (tester) async {
      await pump(tester, const EduLessonScreen(lessonId: 5));
      expect(find.text('1.1 The Foundation of the Church'), findsOneWidget);
      expect(find.text('Lesson notes (PDF)'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget, reason: 'an audio material gives the Listen button');
    });

    testWidgets('taking a practice quiz', (tester) async {
      await pump(tester, const EduAttemptScreen(attemptId: 11));
      expect(find.text('Where was the first Church council held?'), findsOneWidget);
      expect(find.text('Check your answer'), findsOneWidget);
      expect(find.text('Question 1 of 2'), findsOneWidget);
      // Leave no ticking timer behind.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('quiz page', (tester) async {
      await pump(tester, const EduQuizScreen(quizId: 8));
      expect(find.text('Start the quiz'), findsOneWidget);
    });

    testWidgets('progress', (tester) async {
      await pump(tester, const EduProgressScreen());
      expect(find.text('82.5%'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget, reason: 'no published marks = pending, never 0');
    });

    testWidgets('more', (tester) async {
      await pump(tester, const EduMoreScreen());
      expect(find.text('Programs'), findsOneWidget);
    });
  });

  testWidgets('a locked lesson shows the lock and no number', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        sessionProvider.overrideWith(_SignedOutSession.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        home: Scaffold(
          body: Column(children: [
            LessonTile(lesson: const {'id': 1, 'title': 'Ecumenical Councils', 'locked': true, 'status': 'published'}, number: 3),
            LessonTile(lesson: const {'id': 2, 'title': 'Apostolic Church', 'completed': true, 'status': 'published', 'est_minutes': 15}, number: 1),
          ]),
        ),
      ),
    ));
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });
}
