import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_lock.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/admin.dart';
import '../../models/json.dart';
import '../../models/user.dart';
import '../../repositories/providers.dart';
import '../../services/download_service.dart';
import '../../services/preferences_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../app/chrome.dart';
import '../auth/session.dart';
import '../guidance/contextual_help_sheet.dart';
import '../guidance/tour_engine.dart';

/// Settings — design screen "05 Settings": maroon church card, then grouped rows
/// (account, app, notifications, downloads, about) and sign-out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.from});
  final String? from;

  /// Link Telegram (opens the bot with a one-time token) or disconnect it.
  Future<void> _telegram(BuildContext context, WidgetRef ref, bool linked) async {
    final l = context.l10n;
    final repo = ref.read(accountRepositoryProvider);
    if (linked) {
      if (!await showConfirm(context, l.telegramDisconnectConfirm, confirmLabel: l.telegramDisconnect, destructive: true) || !context.mounted) return;
      await runWithProgress(context, () async => ref.read(sessionProvider.notifier).updateUser(await repo.telegramUnlink()));
      return;
    }
    if (!await showConfirm(context, '${l.telegramHint}\n\n${l.telegramOpenBot}', title: l.telegramConnect, confirmLabel: l.telegramConnect) || !context.mounted) return;
    try {
      final url = await runWithProgress(context, repo.telegramLink);
      if (url == null || url.isEmpty) return;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        showInfo(
          context,
          l.isEn
              ? 'The Telegram bot is currently not configured or unavailable on the server. Please check with an administrator.'
              : 'የቴሌግራም ቦቱ በሰርቨሩ ላይ እስካሁን አልተዋቀረም ወይም አይገኝም። እባክዎ አስተዳዳሪውን ያነጋግሩ።',
        );
      }
    }
  }

  /// Administrator diagnostic dialog to test Telegram Bot connection
  Future<void> _showTelegramDiagnostic(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final isEn = l.isEn;
    final adminRepo = ref.read(adminRepositoryProvider);

    Json? diagResult;
    String? testError;
    var testing = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> runTest() async {
            setS(() {
              testing = true;
              testError = null;
            });
            try {
              final res = await adminRepo.testTelegramConnection();
              if (ctx.mounted) {
                setS(() {
                  diagResult = res;
                  testing = false;
                });
              }
            } catch (e) {
              if (ctx.mounted) {
                setS(() {
                  testError = '$e';
                  testing = false;
                });
              }
            }
          }

          if (diagResult == null && !testing && testError == null) {
            runTest();
          }

          final status = asStr(diagResult?['status']) ?? 'testing';
          final botUsername = asStr(diagResult?['bot_username']);
          final botName = asStr(diagResult?['bot_name']);
          final message = asStr(diagResult?['message']);

          final statusColor = switch (status) {
            'connected' => Colors.green,
            'not_configured' => Colors.orange,
            _ => Colors.red,
          };

          final statusLabel = switch (status) {
            'connected' => (isEn ? 'Connected' : 'ተገናኝቷል'),
            'not_configured' => (isEn ? 'Not configured' : 'አልተዋቀረም'),
            'invalid_token' => (isEn ? 'Invalid token' : 'ልክ ያልሆነ ቶከን'),
            _ => (isEn ? 'Connection failed' : 'ግንኙነቱ አልተሳካም'),
          };

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.send_rounded, color: AppColors.gold, size: 22),
                const SizedBox(width: 8),
                Text(isEn ? 'Telegram Bot Connection' : 'የቴሌግራም ቦት ግንኙነት'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (testing)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusLabel,
                        style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (botUsername != null && botUsername.isNotEmpty) ...[
                    Text(
                      '${isEn ? "Bot Username:" : "የቦቱ መጠሪያ፦"} @$botUsername',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (botName != null) ...[
                      const SizedBox(height: 4),
                      Text('${isEn ? "Name:" : "ስም፦"} $botName'),
                    ],
                    const SizedBox(height: 8),
                  ],
                  if (message != null)
                    Text(
                      message,
                      style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                  if (testError != null)
                    Text(
                      testError!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancel),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(isEn ? 'Test Connection' : 'ግንኙነቱን ፈትሽ'),
                onPressed: testing ? null : runTest,
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final user = ref.watch(currentUserProvider);
    final session = ref.watch(sessionProvider);
    final settings = ref.watch(appSettingsProvider);
    final prefsCtrl = ref.read(preferencesProvider.notifier);

    final isFromEdu = from == 'edu';
    final isFromMezmur = from == 'mezmur';
    final isFromHub = from == 'hub';

    // Education administration tools visible from Education module and Hub
    final showEduTools = isFromEdu || isFromHub;
    final showMezmurTools = isFromMezmur || from == null || isFromHub;

    final canPopNow = Navigator.of(context).canPop();

    void handleBack() {
      if (canPopNow) {
        Navigator.of(context).pop();
      } else {
        try {
          if (isFromEdu) {
            context.go('/edu');
          } else if (isFromMezmur) {
            context.go('/home');
          } else {
            context.go('/hub');
          }
        } catch (_) {}
      }
    }

    Future<void> savePref(UserPreferences Function(UserPreferences) change) async {
      try {
        await prefsCtrl.update(change);
      } catch (e) {
        if (context.mounted) showErrorSnack(context, e);
      }
    }

    final canGoBack = from != null || canPopNow;

    return PopScope(
      canPop: canPopNow,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        handleBack();
      },
      child: PatternScaffold(
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 28), children: [
          ScreenTitle(
            l.settings,
            leading: canGoBack
                ? IconButton(
                    key: const ValueKey('settings-back-btn'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: l.back,
                    onPressed: handleBack,
                  )
                : null,
            trailing: const ContextualHelpButton(screenRoute: '/settings'),
          ),
          const SizedBox(height: 14),
          // ---- User data: photo, name, phone; theme switch on the right. Opens the user-data page.
          if (user != null) ...[
            AppCard(
              onTap: () => context.push('/settings/me'),
              padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
              child: Row(children: [
                UserAvatar(user: user, radius: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.userData, style: context.sans(11, color: p.muted, weight: FontWeight.w600)),
                    Text(user.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.serif(16, weight: FontWeight.w600, color: p.text)),
                    Text([if (user.memberId != null) user.memberId!, user.phone].join(' · '), style: context.sans(12, color: p.muted)),
                  ]),
                ),
                const ThemeToggleButton(compact: true),
              ]),
            ),
            SettingsGroup(children: [
              // My attendance lives here only (removed from the program pages).
              SettingsTile(key: const ValueKey('settings-attendance'), icon: Icons.calendar_month_rounded, label: l.myAttendance, onTap: () => context.push('/settings/attendance')),
              SettingsTile(key: const ValueKey('settings-chat'), icon: Icons.forum_outlined, label: l.chatTitle, onTap: () => context.push('/settings/chat')),
              if (showMezmurTools)
                SettingsTile(key: const ValueKey('settings-projects'), icon: Icons.task_alt_rounded, label: l.projectsTitle, onTap: () => context.push('/projects')),
              SettingsTile(key: const ValueKey('settings-notifications'), icon: Icons.notifications_outlined, label: l.notificationSettings, onTap: () => context.push('/settings/notifications')),
            ]),
            // ---- Account & Security consolidation
            SettingsGroup(
              title: l.isEn ? 'Account & Security' : 'መለያ እና ደህንነት',
              children: [
                SettingsTile(key: const ValueKey('settings-change-pin'), icon: Icons.lock_outline_rounded, label: l.changePinTitle, onTap: () => context.push('/settings/password')),
                SettingsTile(key: const ValueKey('settings-sessions'), icon: Icons.devices_rounded, label: l.sessTitle, onTap: () => context.push('/settings/sessions')),
                const _BiometricLockTile(),
                SettingsTile(
                  key: const ValueKey('settings-telegram'),
                  icon: Icons.send_rounded,
                  label: l.telegram,
                  value: user.telegramLinked ? (user.telegramUsername != null ? '@${user.telegramUsername}' : l.telegramLinked) : l.telegramConnect,
                  onTap: () => _telegram(context, ref, user.telegramLinked),
                ),
                if (user.can(Perm.settingsManage) || user.accountType == 'admin')
                  SettingsTile(
                    key: const ValueKey('settings-telegram-diag'),
                    icon: Icons.network_check_rounded,
                    label: l.isEn ? 'Telegram Bot Diagnostic' : 'የቴሌግራም ቦት ምርመራ',
                    onTap: () => _showTelegramDiagnostic(context, ref),
                  ),
              ],
            ),
          ],
          // ---- Education administration: course management and student registration live here.
          if (showEduTools && user != null && user.canAny([Perm.educationManage, Perm.educationRegister, Perm.educationContent]))
            SettingsGroup(title: l.eduSection, children: [
              if (user.can(Perm.educationManage))
                SettingsTile(key: const ValueKey('settings-course-management'), icon: Icons.tune_rounded, label: l.courseManagement, onTap: () => context.push('/edu/manage')),
              if (user.canAny([Perm.educationManage, Perm.educationRegister]))
                SettingsTile(key: const ValueKey('settings-registrations'), icon: Icons.how_to_reg_rounded, label: l.regTitle, onTap: () => context.push('/edu/registrations')),
              if (user.canAny([Perm.educationContent, Perm.educationManage]))
                SettingsTile(key: const ValueKey('settings-edu-content'), icon: Icons.auto_stories_outlined, label: l.elContentTitle, onTap: () => context.push('/edu/content')),
            ]),
          // ---- Mezmur tools
          if (showMezmurTools)
            SettingsGroup(
              title: isFromHub ? (l.isEn ? 'Mezmur Tools' : 'የመዝሙር መተግበሪያ') : null,
              children: [
                SettingsTile(
                  key: const ValueKey('settings-reminder-time'),
                  icon: Icons.alarm_rounded,
                  label: l.reminders,
                  onTap: () => context.push('/settings/reminders'),
                ),
                SettingsTile(
                  key: const ValueKey('settings-downloads'),
                  icon: Icons.download_rounded,
                  label: l.downloadSettings,
                  onTap: () => context.push('/settings/downloads'),
                ),
              ],
            ),
          // ---- App
          SettingsGroup(title: l.appSection, children: [
            SettingsTile(
              key: const ValueKey('settings-language'),
              icon: Icons.language_rounded,
              label: l.language,
              value: settings.locale.languageCode == 'am' ? l.amharic : l.english,
              onTap: () async {
                final code = await showModalBottomSheet<String>(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ListTile(title: Text(l.amharic), onTap: () => Navigator.pop(ctx, 'am')),
                      ListTile(title: Text(l.english), onTap: () => Navigator.pop(ctx, 'en')),
                    ]),
                  ),
                );
                if (code == null) return;
                await ref.read(appSettingsProvider.notifier).setLocale(code);
                await savePref((x) => x.copyWith(language: code));
              },
            ),
          ]),
        // ---- Help & Guidance
        SettingsGroup(
          title: l.isEn ? 'Help & Guidance' : 'እርዳታ እና መመሪያ',
          children: [
            SettingsTile(
              key: const ValueKey('settings-guidance-center'),
              icon: Icons.help_outline_rounded,
              label: l.isEn ? 'Guidance Center' : 'የመመሪያ ማዕከል',
              onTap: () => context.push('/settings/guidance'),
            ),
            SettingsTile(
              key: const ValueKey('settings-restart-tour'),
              icon: Icons.tour_outlined,
              label: l.isEn ? 'Restart Welcome Tour' : 'የመጀመሪያ ገለጻ ጉብኝት ድጋሚ ጀምር',
              onTap: () async {
                await TourController.instance.resetTour('welcome_tour', ref: ref);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l.isEn ? 'Welcome tour reset! Opening Hub...' : 'የመጀመሪያ ገለጻ ጉብኝት እንደገና ተጀምሯል!'),
                    ),
                  );
                  context.go('/hub');
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    TourController.instance.startTour(context, 'welcome_tour', ref: ref, force: true);
                  });
                }
              },
            ),
            SettingsTile(
              key: const ValueKey('settings-report-problem'),
              icon: Icons.report_problem_outlined,
              label: l.isEn ? 'Report a Problem' : 'ችግር ሪፖርት ያድርጉ',
              onTap: () => context.push('/support/report-problem'),
            ),
          ],
        ),
        // ---- Admin
        if (user?.isAdmin ?? false)
          SettingsGroup(title: l.adminSection, children: [
            SettingsTile(icon: Icons.admin_panel_settings_outlined, label: l.adminPanel, onTap: () => context.push('/admin')),
            if (user != null && user.can(Perm.guidanceManage))
              SettingsTile(
                icon: Icons.menu_book_outlined,
                label: l.isEn ? 'Manage Guidance' : 'መመሪያዎችን አስተዳድር',
                onTap: () => context.push('/admin/guidance'),
              ),
            if (session is SignedIn && session.isSystem) SettingsTile(icon: Icons.shield_outlined, label: l.systemConsole, onTap: () => context.push('/system')),
          ]),
        // ---- About
        SettingsGroup(title: l.about, children: [
          SettingsTile(icon: Icons.info_outline_rounded, label: l.aboutApp, onTap: () => context.push('/settings/about')),
          SettingsTile(label: l.version, value: AppConfig.appVersion),
        ]),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
          icon: const Icon(Icons.logout_rounded),
          label: Text(l.logout),
          onPressed: () async {
            final sync = ref.read(syncServiceProvider);
            var pending = await sync.pendingCount();
            if (pending > 0 && ref.read(isOnlineProvider)) {
              await sync.flush().timeout(const Duration(seconds: 4), onTimeout: () {});
              pending = await sync.pendingCount();
            }

            if (!context.mounted) return;

            if (pending > 0) {
              final action = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l.syncPendingLogoutTitle(pending)),
                  content: Text(l.syncPendingLogoutBody(pending)),
                  actions: [
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, 'stay'),
                      child: Text(l.syncStaySignedIn),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: () => Navigator.pop(ctx, 'discard'),
                      child: Text(l.syncDiscardAndLogout),
                    ),
                  ],
                ),
              );

              if (action != 'discard' || !context.mounted) return;

              final confirmed = await showConfirm(
                context,
                l.syncDiscardConfirmBody(pending),
                confirmLabel: l.syncDiscardConfirmBtn,
                destructive: true,
              );

              if (!confirmed || !context.mounted) return;

              await runWithProgress(
                context,
                () => ref.read(sessionProvider.notifier).logout(discard: true).then((_) => true),
              );
            } else {
              if (await showConfirm(context, l.logoutConfirm, confirmLabel: l.logout, destructive: true) && context.mounted) {
                await runWithProgress(context, () => ref.read(sessionProvider.notifier).logout().then((_) => true));
              }
            }
          },
        ),
      ]),
      ),
    );
  }
}

/// Downloads: Wi-Fi only, audio download (on by default) and the downloads manager.
class DownloadSettingsScreen extends ConsumerWidget {
  const DownloadSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(appSettingsProvider);
    final prefs = ref.watch(preferencesProvider);
    final dlBytes = ref.watch(downloadsProvider.select((m) => m.values.fold<int>(0, (s, e) => s + e.sizeBytes)));
    Future<void> savePref(UserPreferences Function(UserPreferences) change) async {
      try {
        await ref.read(preferencesProvider.notifier).update(change);
      } catch (e) {
        if (context.mounted) showErrorSnack(context, e);
      }
    }

    return PatternScaffold(
      appBar: AppBar(title: Text(l.downloadSettings)),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 28), children: [
        SettingsGroup(children: [
          SettingsTile(
            key: const ValueKey('settings-autoplay'),
            icon: Icons.play_circle_outline_rounded,
            label: l.autoplay,
            switchValue: prefs.audioAutoplay,
            onSwitch: (v) => savePref((x) => x.copyWith(audioAutoplay: v)),
          ),
          SettingsTile(label: l.downloadAudio, switchValue: prefs.downloadAudio, onSwitch: (v) => savePref((x) => x.copyWith(downloadAudio: v))),
          SettingsTile(label: l.wifiOnly, switchValue: settings.wifiOnly, onSwitch: (v) => ref.read(appSettingsProvider.notifier).setWifiOnly(v)),
          SettingsTile(label: l.manageDownloads, value: Formatters.fileSize(dlBytes), onTap: () => context.go('/library?tab=downloads')),
        ]),
        Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 0), child: Text(l.downloadAudioHint, style: context.sans(12, color: context.palette.muted))),
      ]),
    );
  }
}


/// Lock this phone's app with the phone's fingerprint (or screen lock): asked when the app opens.
class _BiometricLockTile extends ConsumerStatefulWidget {
  const _BiometricLockTile();
  @override
  ConsumerState<_BiometricLockTile> createState() => _BiometricLockTileState();
}

class _BiometricLockTileState extends ConsumerState<_BiometricLockTile> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lock = ref.watch(appLockProvider);
    return SwitchListTile(
      key: const ValueKey('settings-bio-lock'),
      secondary: const Icon(Icons.fingerprint_rounded),
      title: Text(l.bioLock),
      subtitle: Text(l.bioLockHint),
      value: lock.enabled,
      onChanged: (on) async {
        if (on && !await lock.available()) {
          if (context.mounted) showSnack(context, l.bioUnavailable);
          return;
        }
        await lock.setEnabled(on, l.bioReason);
        if (mounted) setState(() {});
      },
    );
  }
}
