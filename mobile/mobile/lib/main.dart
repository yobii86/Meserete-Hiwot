import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app/app.dart';
import 'core/providers.dart';
import 'core/storage/local_db.dart';
import 'core/storage/local_prefs.dart';
import 'core/storage/secure_store.dart';
import 'core/theme/app_colors.dart';
import 'services/audio_player_service.dart' show AudioArtwork;
import 'services/error_reporting_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ErrorReportingService.initializeAppInfo();

  if (kDebugMode) {
    FlutterError.onError = (details) => FlutterError.dumpErrorToConsole(details, forceReport: true);
  }
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformDispatcher] Uncaught async error: $error');
    return true;
  };

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));

  // Media notification + lock-screen controls (Android/iOS media session).
  if (!kIsWeb) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.mezmur.zelideta.audio',
      androidNotificationChannelName: 'መዝሙር',
      androidNotificationChannelDescription: 'መሠረተ ሕይወት — Mezmur playback',
      androidNotificationIcon: 'drawable/ic_stat_mezmur',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: false,
      notificationColor: AppColors.maroon,
      preloadArtwork: true,
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
    );
    await AudioArtwork.prepare();
  }
  await initializeDateFormatting();

  final store = SecureStore();
  await store.load();
  final prefs = await LocalPrefs.load();
  final db = await LocalDb.open();

  runApp(ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
      localPrefsProvider.overrideWithValue(prefs),
      localDbProvider.overrideWithValue(db),
    ],
    child: const MezmurApp(),
  ));
}
