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
import 'package:mezmur_zelideta/features/edu/admin/edu_attendance_dashboard_screen.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:mezmur_zelideta/repositories/providers.dart';
import 'package:mezmur_zelideta/repositories/superapp_repositories.dart';

import 'fakes.dart';

Future<ApiClient> _createApi(FakeAdapter adapter) async {
  FlutterSecureStorage.setMockInitialValues({'access_token': 't', 'refresh_token': 'r', 'token_scope': 'app', 'device_id': 'd'});
  final store = SecureStore();
  await store.load();
  return ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockDashboardData = {
    'period': {
      'year': 2019,
      'month': null,
      'from_date': '2026-09-11',
      'to_date': '2027-09-10',
      'month_name_am': 'ሁሉም ወራት',
      'month_name_en': 'All Months',
    },
    'kpi': {
      'total_students': 24,
      'total_sessions': 18,
      'present': 120,
      'absent': 14,
      'excused': 6,
      'total_expected': 140,
      'attendance_rate': 85.7,
      'suspended_sessions': 1,
    },
    'analytics': {
      'monthly_trends': [
        {'month': 1, 'month_name_am': 'መስከረም', 'rate': 90.0, 'present': 30, 'absent': 2, 'excused': 1},
        {'month': 2, 'month_name_am': 'ጥቅምት', 'rate': 85.0, 'present': 28, 'absent': 4, 'excused': 1},
      ],
      'by_program': [
        {'id': 1, 'title': 'ነገረ መለኮት ክፍል', 'present': 60, 'total': 70, 'rate': 85.7},
      ],
      'by_class': [
        {'id': 10, 'name': 'ክፍል 10-A', 'present': 50, 'total': 60, 'rate': 83.3},
      ],
      'status_distribution': {'present': 120, 'absent': 14, 'excused': 6},
      'student_ranking': [],
    },
    'students_performance': [
      {
        'id': 101,
        'full_name': 'ዳዊት ዮሐንስ',
        'class_name': 'ክፍል 10-A',
        'present': 15,
        'absent': 1,
        'excused': 0,
        'total': 16,
        'rate': 93.8,
      },
      {
        'id': 102,
        'full_name': 'ሳራ ዳንኤል',
        'class_name': 'ክፍል 10-A',
        'present': 12,
        'absent': 3,
        'excused': 1,
        'total': 16,
        'rate': 75.0,
      },
    ],
    'filters_meta': {
      'academic_years': [
        {'id': 1, 'eth_year': 2019, 'name': '2019 ዓ.ም'},
      ],
      'classes': [
        {'id': 10, 'name': 'ክፍል 10-A'},
      ],
      'programs': [
        {'id': 1, 'title': 'ነገረ መለኮት ክፍል'},
      ],
    },
  };

  final mockStudentProfileData = {
    'student': {
      'id': 101,
      'full_name': 'ዳዊት ዮሐንስ',
      'phone': '0911000000',
      'member_no': 'MZ-101',
      'class_name': 'ክፍል 10-A',
      'grade_name': '10ኛ ክፍል',
      'academic_year_name': '2019 ዓ.ም',
    },
    'summary': {
      'year': 2019,
      'total_scheduled_programs': 3,
      'present_sessions': 15,
      'absent_sessions': 1,
      'excused_sessions': 0,
      'suspended_sessions': 0,
      'total_expected': 16,
      'attendance_rate': 93.8,
    },
    'records': [
      {
        'id': 501,
        'program_id': 1,
        'program_title': 'ነገረ መለኮት ክፍል',
        'category_name': 'የትምህርት መርሐግብር',
        'occurrence_date': '2026-09-20',
        'calendar_date': 'መስከረም 10 ቀን 2019 ዓ.ም',
        'status': 'present',
        'attended_at': '2026-09-20 08:30:00',
        'has_signature': true,
        'signature_status': 'signed',
        'recorder_name': 'መምህር ተክለ',
        'class_name': 'ክፍል 10-A',
        'course_name': 'ነገረ መለኮት',
      },
    ],
  };

  group('Education Attendance Dashboard UI/UX Tests', () {
    testWidgets('Dashboard renders 13-month bar, KPI cards and toggles tabs', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final api = await _createApi(FakeAdapter((req) {
        if (req.path == '/edu/admin/attendance/dashboard') {
          return (status: 200, body: ok(mockDashboardData));
        }
        if (req.path == '/edu/admin/attendance/student/101') {
          return (status: 200, body: ok(mockStudentProfileData));
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      }));

      final adminUser = AppUser.fromJson({
        'id': 1,
        'phone': '0911000000',
        'full_name': 'Admin User',
        'roles': ['admin'],
        'permissions': ['education.attendance_view', 'education.manage'],
        'account_type': 'admin',
        'status': 'active',
        'membership_status': 'active',
        'token_version': 1,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            eduRepositoryProvider.overrideWithValue(EduRepository(api)),
            currentUserProvider.overrideWith((ref) => adminUser),
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
            home: const EduAttendanceDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify AppBar and Title
      expect(find.text('የትምህርት ክትትል ዳሽቦርድ'), findsOneWidget);

      // 2. Verify Ethiopian Calendar Month Navigation Chips
      expect(find.text('ሁሉም ወራት'), findsAtLeastNWidgets(1));
      expect(find.text('መስከረም'), findsAtLeastNWidgets(1));
      expect(find.text('ጳጉሜ'), findsAtLeastNWidgets(1));

      // 3. Verify Top KPI summary cards
      expect(find.text('ጠቅላላ ተማሪዎች'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('የመርሐግብር ክፍለ ጊዜ'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('85.7%'), findsAtLeastNWidgets(1));

      // 4. Verify Visual Analytics Header
      expect(find.text('የክትትል ትንታኔ እና አፈጻጸም'), findsOneWidget);

      // 5. Verify the two primary tabs exist
      expect(find.text('የተማሪዎች ክትትል'), findsOneWidget);
      expect(find.text('የመርሐግብር አፈጻጸም'), findsOneWidget);

      // 6. Switch to Program Performance Tab
      await tester.tap(find.text('የመርሐግብር አፈጻጸም'));
      await tester.pumpAndSettle();

      // Verify Table Columns and Student Performance Rows
      expect(find.text('የተማሪዎች ክትትል አፈጻጸም ሠንጠረዥ'), findsOneWidget);
      expect(find.text('ዳዊት ዮሐንስ'), findsOneWidget);
      expect(find.text('ሳራ ዳንኤል'), findsOneWidget);
      expect(find.text('93.8%'), findsOneWidget);
      expect(find.text('75.0%'), findsOneWidget);
    });
  });
}

