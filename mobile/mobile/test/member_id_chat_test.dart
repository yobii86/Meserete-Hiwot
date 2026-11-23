import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mezmur_zelideta/app/chrome.dart';
import 'package:mezmur_zelideta/core/l10n/l10n.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/providers.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/core/utils/formatters.dart';
import 'package:mezmur_zelideta/features/chat/chat_screens.dart';
import 'package:mezmur_zelideta/l10n/app_localizations_am.dart';
import 'package:mezmur_zelideta/l10n/app_localizations_en.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:mezmur_zelideta/services/audio_player_service.dart';
import 'package:mezmur_zelideta/widgets/qr.dart';

import 'fakes.dart';

Future<ApiClient> _api(FakeAdapter adapter) async {
  FlutterSecureStorage.setMockInitialValues({'access_token': 'a1', 'refresh_token': 'r1', 'token_scope': 'app', 'device_id': 'android-test-device'});
  final store = SecureStore();
  await store.load();
  return ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
}

Widget _wrap(Widget child, ApiClient api, {Locale locale = const Locale('en')}) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

Map<String, dynamic> _msg(int id, String body, {bool mine = false, String name = 'አበበ', String memberId = 'መ/ሕ/ወ/17', bool leader = false, String kind = 'text', Map<String, dynamic>? meeting}) => {
      'id': id,
      'department_id': 3,
      'thread': 'group',
      'kind': kind,
      'body': body,
      'deleted': false,
      'sender': {'id': mine ? 1 : 2, 'full_name': name, 'member_id': memberId, 'is_leader': leader},
      'attachment': null,
      'meeting': meeting,
      'mine': mine,
      'created_at': '2026-09-24T07:30:00Z',
    };

void main() {
  setUpAll(() async => initializeDateFormatting());

  group('Ethiopian calendar in both languages', () {
    test('English shows Ethiopian dates too (storage stays Gregorian)', () {
      final f = Formatters(AppLocalizationsEn(), 'en');
      expect(f.date(DateTime(2026, 9, 24)), 'Meskerem 14, 2019 E.C.');
      expect(f.shortDate(DateTime(2026, 9, 24)), 'Meskerem 14');
      expect(f.monthYear(DateTime(2026, 9, 24)), 'Meskerem 2019');
      expect(f.date(DateTime(2026, 9, 10)), 'Pagume 5, 2018 E.C.');
      expect(f.date(DateTime(2026, 9, 24), withWeekday: true), startsWith('Thu'));
      expect(f.gregorianDate(DateTime(2026, 9, 24)), 'Sep 24, 2026');
    });

    test('Amharic is unchanged', () {
      final f = Formatters(AppLocalizationsAm(), 'am');
      expect(f.date(DateTime(2026, 9, 24)), 'መስከረም 14፣ 2019 ዓ.ም');
      expect(f.monthYear(DateTime(2026, 9, 24)), 'መስከረም 2019');
    });
  });

  group('Mezmur navigation', () {
    test('the Mezmur section has a Categories button at index 1', () {
      const nav = NavLayout(section: HomeSection.mezmur, branch: 0, location: '/home');
      expect(nav.hasCategories, isTrue);
      expect(nav.selectedIndex, 0);
      expect(nav.branchFor(0), 0);
      expect(nav.branchFor(1), isNull); // categories
      expect(nav.branchFor(2), 1); // library
      expect(nav.branchFor(4), 3); // settings
      expect(const NavLayout(section: HomeSection.mezmur, branch: 0, location: '/home/categories').selectedIndex, 1);
      expect(const NavLayout(section: HomeSection.mezmur, branch: 2, location: '/programs').selectedIndex, 3);
    });

    test('the bottom bar is on the Mezmur home and pages, not on the hub', () {
      expect(const NavLayout(section: HomeSection.mezmur, branch: 0, location: '/home').showsBottomBar, isTrue);
      expect(const NavLayout(section: HomeSection.mezmur, branch: 0, location: '/home/mezmur/3').showsBottomBar, isTrue);
      expect(const NavLayout(section: HomeSection.education, branch: 0, location: '/edu').showsBottomBar, isTrue);
      expect(const NavLayout(section: HomeSection.hub, branch: 0, location: '/hub').showsBottomBar, isFalse);
    });

    test('the hub keeps its four tabs (no Mezmur categories)', () {
      const nav = NavLayout(section: HomeSection.hub, branch: 0, location: '/hub');
      expect(nav.hasCategories, isFalse);
      expect(nav.isEducation, isFalse);
      expect(nav.selectedIndex, 0);
      expect(nav.branchFor(2), 2);
      expect(nav.branchFor(1), 1); // My Library
      expect(homeSectionOf('/home/categories'), HomeSection.mezmur);
    });

    test('ትምህርት has its own tabs: Home · Class · My Library · Progress · Settings', () {
      const nav = NavLayout(section: HomeSection.education, branch: 0, location: '/edu');
      expect(nav.isEducation, isTrue);
      expect(nav.hasCategories, isFalse);
      for (var i = 0; i < 5; i++) {
        expect(nav.branchFor(i), isNull);
      }
      expect([for (var i = 0; i < 5; i++) nav.routeFor(i)], ['/edu', '/edu/classes', '/edu/library', '/edu/progress', '/settings?from=edu']);
      NavLayout at(String p, [int branch = 0]) => NavLayout(section: HomeSection.education, branch: branch, location: p);
      expect(at('/edu').selectedIndex, 0);
      expect(at('/edu/learn/lesson/4').selectedIndex, 1);
      expect(at('/edu/search').selectedIndex, 0);
      expect(at('/edu/class/2').selectedIndex, 1);
      expect(at('/edu/course/2').selectedIndex, 1);
      expect(at('/edu/library').selectedIndex, 2);
      expect(at('/edu/borrowings').selectedIndex, 2);
      expect(at('/edu/progress').selectedIndex, 3);
      expect(at('/edu/quiz/9').selectedIndex, 3);
      expect(at('/settings').selectedIndex, 4);
      expect(const NavLayout(section: HomeSection.mezmur, branch: 0, location: '/home').routeFor(1), '/home/categories');
    });
  });

  group('member IDs', () {
    test('the profile carries the formatted ID and the permanent number', () {
      final u = AppUser.fromJson({'id': 5, 'full_name': 'ሰላም', 'phone': '+251911', 'member_no': 17, 'member_id': 'መ/ሕ/ባ/17', 'member_group': 'married'});
      expect(u.memberNo, 17);
      expect(u.memberId, 'መ/ሕ/ባ/17');
      final again = AppUser.fromJson(u.toJson());
      expect(again.memberId, 'መ/ሕ/ባ/17');
    });

    testWidgets('the member card shows the ID', (tester) async {
      final api = await _api(FakeAdapter((_) => (status: 200, body: ok(null))));
      await tester.pumpWidget(_wrap(const Scaffold(body: SingleChildScrollView(child: MemberCard(card: {'full_name': 'አበበ ከበደ', 'member_id': 'መ/ሕ/ወ/17', 'departments': [], 'classes': []}))), api));
      expect(find.text('መ/ሕ/ወ/17'), findsOneWidget);
    });
  });

  group('audio notification', () {
    test('track info: title, app name as artist, lyrics excerpt, cover or branded artwork', () {
      expect(lyricsPreview('\n  ቅዱስ ቅዱስ  \n\nቅዱስ እግዚአብሔር\nሦስተኛ'), 'ቅዱስ ቅዱስ / ቅዱስ እግዚአብሔር');
      AudioArtwork.fallback = Uri.parse('file:///data/media_artwork.jpg');
      const t = PlayerTrack(id: 9, title: 'ሰላም ለኪ', subtitle: 'የማርያም', source: 'https://x/a.mp3', lyrics: 'ሰላም ለኪ / ማርያም', durationSec: 120);
      final m = AudioController.mediaItemOf(t);
      expect(m.title, 'ሰላም ለኪ');
      expect(m.artist, 'መሠረተ ሕይወት');
      expect(m.album, 'የማርያም');
      expect(m.displaySubtitle, 'ሰላም ለኪ / ማርያም');
      expect(m.artUri.toString(), 'file:///data/media_artwork.jpg');
      expect(m.duration, const Duration(seconds: 120));
      const withCover = PlayerTrack(id: 9, title: 'x', source: 'https://x/a.mp3', artUrl: 'https://x/c.jpg');
      expect(AudioController.mediaItemOf(withCover).artUri.toString(), 'https://x/c.jpg');
    });
  });

  group('department chat', () {
    Future<(FakeAdapter, ApiClient)> setup({required bool leader, List<Map<String, dynamic>>? items}) async {
      final adapter = FakeAdapter((r) {
        if (r.method == 'GET' && r.path == '/chat/3/messages') {
          return (status: 200, body: ok({
            'department': {'id': 3, 'name': 'የመዝሙር ክፍል', 'name_en': 'Hymns'},
            'thread': 'group',
            'can_send_media': leader,
            'is_leader': leader,
            'items': r.queryParameters['after'] != null ? [] : (items ?? [_msg(1, 'ሰላም ለሁላችሁ', name: 'መሪ ዳዊት', leader: true, memberId: 'መ/ሕ/ወ/3'), _msg(2, 'እሺ', mine: true)]),
          }));
        }
        if (r.method == 'POST' && r.path == '/chat/3/messages') {
          return (status: 201, body: ok(_msg(3, '${body(r)['body']}', mine: true)));
        }
        return (status: 200, body: ok(null));
      });
      return (adapter, await _api(adapter));
    }

    testWidgets('shows history with the sender and member ID; members have no attach button', (tester) async {
      final (adapter, api) = await setup(leader: false);
      await tester.pumpWidget(_wrap(const ConversationScreen(departmentId: 3, thread: 'group'), api));
      await tester.pumpAndSettle();
      expect(find.text('Hymns'), findsOneWidget);
      expect(find.text('ሰላም ለሁላችሁ'), findsOneWidget);
      expect(find.text('መሪ ዳዊት'), findsOneWidget);
      expect(find.text('መ/ሕ/ወ/3'), findsOneWidget);
      expect(find.textContaining('Leader'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-attach')), findsNothing);
      // marks the conversation read up to the last message
      expect(adapter.requests.any((r) => r.path == '/chat/3/read' && body(r)['last_id'] == 2), isTrue);

      await tester.enterText(find.byKey(const ValueKey('chat-input')), 'ነገ እመጣለሁ');
      await tester.tap(find.byKey(const ValueKey('chat-send')));
      await tester.pumpAndSettle();
      final sent = adapter.requests.where((r) => r.method == 'POST' && r.path == '/chat/3/messages').single;
      expect(body(sent), {'thread': 'group', 'body': 'ነገ እመጣለሁ'});
      expect(find.text('ነገ እመጣለሁ'), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // dispose: stops polling
    });

    testWidgets('leaders get the attach menu with the voice-meeting link; meeting cards can be joined', (tester) async {
      final (_, api) = await setup(leader: true, items: [
        _msg(5, 'የክፍሉ ስብሰባ', kind: 'meeting', leader: true, meeting: {'url': 'https://meet.jit.si/mezmur', 'at': '2026-09-25T15:00:00Z'}),
      ]);
      await tester.pumpWidget(_wrap(const ConversationScreen(departmentId: 3, thread: 'group'), api));
      await tester.pumpAndSettle();
      expect(find.text('Voice meeting'), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);
      expect(find.text('meet.jit.si'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chat-attach')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-attach-meeting')), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('chat list shows each department with unread counts and the voice limitation', (tester) async {
      final api = await _api(FakeAdapter((r) => (status: 200, body: ok([
            {
              'department': {'id': 3, 'name': 'የመዝሙር ክፍል', 'name_en': 'Hymns'},
              'is_leader': false,
              'is_member': true,
              'unread_group': 2,
              'unread_private': 1,
              'last_message': _msg(9, 'ሰላም', name: 'ዳዊት'),
            },
          ]))));
      await tester.pumpWidget(_wrap(const ChatListScreen(), api));
      await tester.pumpAndSettle();
      expect(find.text('Hymns'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('ዳዊት: ሰላም'), findsOneWidget);
      expect(find.textContaining('cannot carry live voice calls'), findsOneWidget);
    });
  });
}
