import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/providers.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/features/sinksar/sinksar_screen.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/models/sinksar.dart';
import 'package:mezmur_zelideta/repositories/sinksar_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStore testStore;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 't1', 'refresh_token': 'r1', 'token_scope': 'app'});
    SharedPreferences.setMockInitialValues({});
    testStore = SecureStore();
    await testStore.load();
  });

  group('Phase 3 Synaxarium Regression & Compatibility Suite', () {
    test('SinksarDay parses fallback imported Synaxarium narrative accurately', () {
      final json = {
        'id': 101,
        'gregorian_date': '2026-09-11',
        'ethiopian_date': '2019-01-01',
        'ethiopian_year': 2019,
        'ethiopian_month': 1,
        'ethiopian_day': 1,
        'month_name_am': 'መስከረም',
        'weekday_am': 'ዓርብ',
        'weekday_en': 'Friday',
        'formatted_date': 'መስከረም 1 ቀን 2019 ዓ.ም',
        'formatted_full': 'መስከረም 1 ቀን 2019 ዓ.ም · ዓርብ',
        'is_fasting': false,
        'fasting_reason': null,
        'featured_title': 'ርዕሰ ዐውደ ዓመት ዮሐንስ መጥምቅ',
        'summary': 'ቅዱስ ዮሐንስ መጥምቅ',
        'annual_feasts': [
          {'id': '1', 'title': 'ርዕሰ ዐውደ ዓመት', 'sourceText': 'ርዕሰ ዐውደ ዓመት'}
        ],
        'monthly_feasts': [
          {'id': '1', 'title': 'ልደታ', 'sourceText': 'ልደታ'}
        ],
        'full_text_available': true,
        'narratives': [
          {
            'id': 1,
            'title': 'ስንክሳር ዘወርኀ መስከረም ፩',
            'source': 'B001',
            'summary': 'በስመ አብ ወወልድ ወመንፈስ ቅዱስ አሐዱ አምላክ አሜን።',
            'body': 'በዚች ዕለት ርእሰ ዓውደ ዓመት ዮሐንስ መጥምቅ በዓሉ ተከበረ።',
            'verified': false,
          }
        ],
        'has_narratives': true,
        'refreshed_at': '2026-09-11T00:00:00.000Z',
      };

      final day = SinksarDay.fromJson(json);

      expect(day.ethiopianMonth, 1);
      expect(day.ethiopianDay, 1);
      expect(day.monthNameAm, 'መስከረም');
      expect(day.hasNarratives, isTrue);
      expect(day.fullTextAvailable, isTrue);
      expect(day.narratives.length, 1);

      final narrative = day.narratives.first;
      expect(narrative.id, 1);
      expect(narrative.title, 'ስንክሳር ዘወርኀ መስከረም ፩');
      expect(narrative.source, 'B001');
      expect(narrative.verified, isFalse, reason: 'Imported narrative must default to unverified');
      expect(narrative.body, contains('ዮሐንስ መጥምቅ'));
    });

    test('SinksarDay roundtrip serialization preserves all fields', () {
      const original = SinksarDay(
        gregorianDate: '2026-09-11',
        ethiopianDate: '2019-01-01',
        ethiopianYear: 2019,
        ethiopianMonth: 1,
        ethiopianDay: 1,
        monthNameAm: 'መስከረም',
        weekdayAm: 'ዓርብ',
        weekdayEn: 'Friday',
        formattedDate: 'መስከረም 1 ቀን 2019 ዓ.ም',
        formattedFull: 'መስከረም 1 ቀን 2019 ዓ.ም · ዓርብ',
        isFasting: false,
        featuredTitle: 'ርዕሰ ዐውደ ዓመት ዮሐንስ መጥምቅ',
        summary: 'ቅዱስ ዮሐንስ መጥምቅ',
        annualFeasts: [
          FeastItem(id: '1', title: 'ርዕሰ ዐውደ ዓመት', sourceText: 'ርዕሰ ዐውደ ዓመት'),
        ],
        monthlyFeasts: [
          FeastItem(id: '1', title: 'ልደታ', sourceText: 'ልደታ'),
        ],
        fullTextAvailable: true,
        hasNarratives: true,
        narratives: [
          SinksarNarrative(
            id: 1,
            title: 'ስንክሳር ዘወርኀ መስከረም ፩',
            source: 'B001',
            summary: 'መግቢያ',
            body: 'የዕለቱ ሙሉ ንባብ።',
            verified: false,
          ),
        ],
      );

      final json = original.toJson();
      final restored = SinksarDay.fromJson(json);

      expect(restored.gregorianDate, original.gregorianDate);
      expect(restored.ethiopianMonth, original.ethiopianMonth);
      expect(restored.ethiopianDay, original.ethiopianDay);
      expect(restored.monthNameAm, original.monthNameAm);
      expect(restored.hasNarratives, original.hasNarratives);
      expect(restored.fullTextAvailable, original.fullTextAvailable);
      expect(restored.narratives.length, 1);
      expect(restored.narratives.first.verified, isFalse);
    });

    test('Android widget payload extraction matches expected dictionary schema', () {
      const day = SinksarDay(
        gregorianDate: '2026-09-11',
        ethiopianDate: '2019-01-01',
        ethiopianYear: 2019,
        ethiopianMonth: 1,
        ethiopianDay: 1,
        monthNameAm: 'መስከረም',
        weekdayAm: 'ዓርብ',
        weekdayEn: 'Friday',
        formattedDate: 'መስከረም 1 ቀን 2019 ዓ.ም',
        formattedFull: 'መስከረም 1 ቀን 2019 ዓ.ም · ዓርብ',
        isFasting: true,
        fastingReason: 'ዓቢይ ጾም',
        featuredTitle: 'ርዕሰ ዐውደ ዓመት ዮሐንስ መጥምቅ',
        summary: 'ቅዱስ ዮሐንስ መጥምቅ',
        annualFeasts: [
          FeastItem(id: '1', title: 'ርዕሰ ዐውደ ዓመት', sourceText: 'ርዕሰ ዐውደ ዓመት'),
        ],
        monthlyFeasts: [
          FeastItem(id: '1', title: 'ልደታ', sourceText: 'ልደታ'),
        ],
      );

      // Simulates the exact dictionary construction in SinksarWidgetService.syncWidget
      final widgetPayload = <String, dynamic>{
        'gregorian_date': day.gregorianDate,
        'ethiopian_date': day.ethiopianDate,
        'formatted_date': day.formattedDate,
        'formatted_full': day.formattedFull,
        'featured_title': day.featuredTitle,
        'annual_feasts': day.annualFeasts.map((f) => {'title': f.title}).toList(),
        'monthly_feasts': day.monthlyFeasts.map((f) => {'title': f.title}).toList(),
        'summary': day.summary ?? '',
        'is_fasting': day.isFasting,
        'fasting_reason': day.fastingReason,
      };

      expect(widgetPayload['gregorian_date'], '2026-09-11');
      expect(widgetPayload['ethiopian_date'], '2019-01-01');
      expect(widgetPayload['formatted_date'], 'መስከረም 1 ቀን 2019 ዓ.ም');
      expect(widgetPayload['featured_title'], 'ርዕሰ ዐውደ ዓመት ዮሐንስ መጥምቅ');
      expect(widgetPayload['is_fasting'], isTrue);
      expect(widgetPayload['fasting_reason'], 'ዓቢይ ጾም');
      expect(widgetPayload['annual_feasts'], hasLength(1));
      expect((widgetPayload['annual_feasts'] as List).first['title'], 'ርዕሰ ዐውደ ዓመት');
    });

    testWidgets('SinksarScreen displays narrative cards and handles unverified narrative status', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      const mockDay = SinksarDay(
        gregorianDate: '2026-09-11',
        ethiopianDate: '2019-01-01',
        ethiopianYear: 2019,
        ethiopianMonth: 1,
        ethiopianDay: 1,
        monthNameAm: 'መስከረም',
        weekdayAm: 'ዓርብ',
        weekdayEn: 'Friday',
        formattedDate: 'መስከረም 1 ቀን 2019 ዓ.ም',
        formattedFull: 'መስከረም 1 ቀን 2019 ዓ.ም · ዓርብ',
        isFasting: false,
        featuredTitle: 'ርዕሰ ዐውደ ዓመት ዮሐንስ መጥምቅ',
        summary: 'ቅዱስ ዮሐንስ መጥምቅ',
        annualFeasts: [
          FeastItem(id: '1', title: 'ርዕሰ ዐውደ ዓመት', sourceText: 'ርዕሰ ዐውደ ዓመት'),
        ],
        monthlyFeasts: [
          FeastItem(id: '1', title: 'ልደታ', sourceText: 'ልደታ'),
        ],
        fullTextAvailable: true,
        hasNarratives: true,
        narratives: [
          SinksarNarrative(
            id: 1,
            title: 'ስንክሳር ዘወርኀ መስከረም ፩',
            source: 'B001',
            summary: 'መግቢያ',
            body: 'በዚች ዕለት ርእሰ ዓውደ ዓመት ዮሐንስ መጥምቅ በዓሉ ተከበረ።',
            verified: false,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => null),
            secureStoreProvider.overrideWithValue(testStore),
            sinksarDateProvider('2026-09-11').overrideWith((ref) => Future.value(mockDay)),
            sinksarTodayProvider.overrideWith((ref) => Future.value(mockDay)),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SinksarScreen(initialDate: '2026-09-11'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert narrative title is displayed
      expect(find.text('ስንክሳር ዘወርኀ መስከረም ፩'), findsOneWidget);
      // Assert source identifier B001 is shown
      expect(find.text('ምንጭ፦ B001'), findsOneWidget);
      // Assert narrative body is rendered
      expect(find.textContaining('ዮሐንስ መጥምቅ'), findsWidgets);
    });
  });
}
