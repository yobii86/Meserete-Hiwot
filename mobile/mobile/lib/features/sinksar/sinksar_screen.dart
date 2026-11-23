import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/sinksar.dart';
import '../../repositories/sinksar_repository.dart';
import '../../services/error_reporting_service.dart';
import '../../services/local_notifications.dart';
import '../../services/sinksar_widget_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/ethiopian_date_picker.dart';
import '../../widgets/states.dart';
import '../auth/session.dart' show currentUserProvider;

/// Complete Sinksar Reading Experience Screen — Phase 4 & Phase 7
/// Features date navigation, annual feasts, monthly feasts, full narratives, fasting info,
/// and complete Ethiopian Orthodox Tewahedo branding.
class SinksarScreen extends ConsumerStatefulWidget {
  const SinksarScreen({super.key, this.initialDate});
  final String? initialDate;

  @override
  ConsumerState<SinksarScreen> createState() => _SinksarScreenState();
}

class _SinksarScreenState extends ConsumerState<SinksarScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _selectedDate = DateTime.tryParse(widget.initialDate!) ?? DateTime.now();
    } else {
      _selectedDate = DateTime.now();
    }
  }

  String get _currentDateIso => _selectedDate.toIso8601String().substring(0, 10);

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  void _jumpToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showEthiopianDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _share(SinksarDay day, bool isEn) {
    final buf = StringBuffer();
    buf.writeln('✝️ መሠረተ ሕይወት — የዕለቱ ስንክሳር');
    buf.writeln('📅 ${day.formattedFull}');
    if (day.isFasting) {
      buf.writeln('🕊️ ${day.fastingReason ?? "የጾም ቀን"}');
    }
    buf.writeln('');
    if (day.annualFeasts.isNotEmpty) {
      buf.writeln('📌 ዓመታዊ በዓላት፦');
      for (final f in day.annualFeasts) {
        buf.writeln('• ${f.title}');
      }
      buf.writeln('');
    }
    if (day.monthlyFeasts.isNotEmpty) {
      buf.writeln('📌 ወርኀዊ በዓላት፦');
      for (final f in day.monthlyFeasts) {
        buf.writeln('• ${f.title}');
      }
      buf.writeln('');
    }
    buf.writeln('በመሠረተ ሕይወት መተግበሪያ የተላከ።');
    SharePlus.instance.share(ShareParams(text: buf.toString(), subject: 'መሠረተ ሕይወት — የዕለቱ ስንክሳር'));
  }

  Future<void> _confirmAndSendTestNotification(bool isEn) async {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: AppColors.gold, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEn ? 'Test Sinksar Lock-Screen Notification' : 'የስንክሳር የሙከራ ማሳወቂያ (Lock Screen)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isEn
                      ? 'Choose how to test the Sinksar notification for $_currentDateIso on your device:'
                      : 'ለ$_currentDateIso የሚሆነውን የስንክሳር ማሳወቂያ በስልክዎ ለመሞከር ይምረጡ፦',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.screen_lock_portrait_rounded, color: AppColors.gold),
                  ),
                  title: Text(
                    isEn ? 'Instant Lock-Screen Preview (Local)' : 'ወዲያውኑ በስልክዎ ላይ ሞክር (Lock-Screen Preview)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(isEn
                      ? 'Fires an immediate local notification with public lock-screen visibility so you can lock your screen and test.'
                      : 'ወዲያውኑ በስልክዎ ላይ ማሳወቂያ ያሳያል፤ ስልክዎን ቆልፈው በLock Screen ላይ ማየት ይችላሉ።'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final day = ref.read(sinksarDateProvider(_currentDateIso)).asData?.value;
                    final title = 'የዕለቱ ስንክሳር — ${day?.formattedDate ?? _currentDateIso}';
                    final body = '${day?.ethiopianDate ?? _currentDateIso} (${day?.weekdayAm ?? ""}) • የዛሬ ቅዱሳን፦ ${day?.featuredTitle ?? "የዕለቱ ስንክሳር"}';
                    await ref.read(localNotificationsProvider).show(
                          id: 0x53494E,
                          title: title,
                          body: body,
                          channel: Channels.sinksar,
                          channelName: 'የዕለቱ ስንክሳር (Daily Synaxarium)',
                          payload: 'sinksar:$_currentDateIso',
                        );
                    if (mounted) {
                      showSnack(
                        context,
                        isEn
                            ? 'Notification sent. Lock your phone to verify lock-screen display.'
                            : 'ማሳወቂያው ተልኳል። ስልክዎን ቆልፈው በLock Screen ላይ ይመልከቱ።',
                      );
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.maroon.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.cloud_upload_rounded, color: AppColors.maroon),
                  ),
                  title: Text(
                    isEn ? 'Server Push Notification (FCM)' : 'ከአገልጋይ የሚላክ የፑሽ ማሳወቂያ (Server Push)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(isEn
                      ? 'Submits request to production server to push only to your registered device token.'
                      : 'በዚህ አካውንት ወደተመዘገበው ስልክዎ ብቻ እንዲላክ ከአገልጋዩ ጥያቄ ያቀርባል።'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    _sendServerTestNotification(isEn);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendServerTestNotification(bool isEn) async {
    showSnack(context, isEn ? 'Submitting test notification to server...' : 'የሙከራ ማሳወቂያውን በመላክ ላይ...');
    try {
      final res = await ref.read(sinksarRepositoryProvider).sendTestNotification(targetDate: _currentDateIso);
      if (!mounted) return;

      final tokensCount = res['tokens_count'] ?? res['devices_targeted'] ?? 0;
      final status = res['status'] ?? 'unknown';

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isEn ? 'Notification Submission Result' : 'የማሳወቂያ መላክ ውጤት'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn
                    ? 'Server successfully processed test notification request.'
                    : 'አገልጋዩ (Server) ጥያቄውን በተሳካ ሁኔታ አጠናቋል።',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text('Status: $status'),
              Text('${isEn ? "Target Device Tokens" : "የተገኙ የመሣሪያ ቶከኖች"}: $tokensCount'),
              const SizedBox(height: 8),
              Text(
                isEn
                    ? 'Note: Device receipt and lock-screen visibility depend on Android notification permissions and system lock-screen settings.'
                    : 'ማስታወሻ፦ ማሳወቂያው በስክሪኑ ላይ መታየቱ የስልክዎ የማሳወቂያ ፈቃድና የLock Screen ቅንብር ላይ የተመሰረተ ነው።',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isEn ? 'OK' : 'እሺ'),
            ),
          ],
        ),
      );
    } catch (e, st) {
      if (!mounted) return;
      final repId = await ref.read(errorReportingServiceProvider).recordError(
        module: 'sinksar',
        screen: 'SinksarScreen',
        operation: 'send_test_notification',
        error: e,
        stackTrace: st,
        endpoint: '/sinksar/test-notification',
      );
      if (!mounted) return;
      showSnack(context, '${isEn ? "Test notification failed" : "ማሳወቂያውን መላክ አልተቻለም"} ($repId): $e');
    }
  }

  Future<void> _showAddWidgetDialog(bool isEn) async {
    final service = ref.read(sinksarWidgetServiceProvider);
    final status = await service.isWidgetPinned();

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.widgets_rounded, color: AppColors.gold, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEn ? 'Add Sinksar Widget to Home Screen' : 'የስንክሳር ዊጀት ወደ ስልክ ስክሪን ጨምር',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isEn
                    ? 'Place the daily Orthodox Tewahedo Sinksar directly on your Android home screen for instant daily spiritual remembrance.'
                    : 'የዕለቱ የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ስንክሳር እና መታሰቢያ ሁልጊዜ በስልክዎ ዋና ስክሪን ላይ እንዲታይ ከታች ካሉት መጠኖች አንዱን ይምረጡ።',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.maroon.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.crop_square_rounded, color: AppColors.maroon),
                  ),
                  title: Text(
                    isEn ? 'Compact Widget (2×1)' : 'አጭር ዊጀት (Compact 2×1)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(isEn
                      ? 'Displays Ethiopian date and main commemoration'
                      : 'የዕለቱ የኢትዮጵያ ቀን እና ዋና መታሰቢያ'),
                  trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.gold),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final pinned = await service.requestPinWidget(expanded: false);
                    if (!mounted) return;
                    if (pinned) {
                      showSnack(context, isEn ? 'Widget pin request sent' : 'የአጭር ዊጀት ጥያቄ ወደ ስልክዎ ተልኳል');
                    } else {
                      _showManualWidgetHelp(isEn);
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.view_agenda_rounded, color: AppColors.gold),
                  ),
                  title: Text(
                    isEn ? 'Expanded Widget (4×2)' : 'ዝርዝር ዊጀት (Expanded 4×2)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(isEn
                      ? 'Ethiopian/Gregorian date, annual & monthly feasts, summary & refresh'
                      : 'የኢትዮጵያና ፈረንጅ ቀን፣ ዓመታዊና ወርኀዊ በዓላት፣ ማጠቃለያና ማደሻ'),
                  trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.gold),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final pinned = await service.requestPinWidget(expanded: true);
                    if (!mounted) return;
                    if (pinned) {
                      showSnack(context, isEn ? 'Widget pin request sent' : 'የዝርዝር ዊጀት ጥያቄ ወደ ስልክዎ ተልኳል');
                    } else {
                      _showManualWidgetHelp(isEn);
                    }
                  },
                ),
                if (status.hasWidgets) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        isEn
                            ? 'Sinksar widget is active on your Home Screen'
                            : 'የስንክሳር ዊጀት በስልክዎ ዋና ስክሪን ላይ ተቀምጧል',
                        style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showManualWidgetHelp(bool isEn) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'How to Add Widget' : 'ዊጀቱን እንዴት ማከል እንደሚችሉ'),
        content: Text(isEn
            ? '1. Go to your phone\'s Home Screen.\n2. Long-press on any empty space.\n3. Tap "Widgets".\n4. Scroll to "መሠረተ ሕይወት" and drag the Sinksar widget onto your screen.'
            : '1. ወደ ስልክዎ ዋና ገጽ (Home Screen) ይሂዱ።\n2. ባዶ ቦታን ተጭነው ይያዙ (Long press)።\n3. ከሚመጡት አማራጮች «Widgets» የሚለውን ይንኩ።\n4. «መሠረተ ሕይወት» ስር የሚገኘውን የስንክሳር ዊጀት መርጠው ወደ ስክሪኑ ይጎትቱ።'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isEn ? 'Understood' : 'ተረድቻለሁ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.localeName.startsWith('en');
    final user = ref.watch(currentUserProvider);
    final sinksarAsync = ref.watch(sinksarDateProvider(_currentDateIso));

    return PatternScaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Synaxarium (Sinksar)' : 'መጽሐፈ ስንክሳር'),
        actions: [
          IconButton(
            icon: const Icon(Icons.widgets_outlined, color: AppColors.gold),
            tooltip: isEn ? 'Add Home-Screen Widget' : 'ወደ ስልክ ስክሪን ጨምር (Widget)',
            onPressed: () => _showAddWidgetDialog(isEn),
          ),
          if ((user?.isAdmin ?? false) || (user?.isSuperAdmin ?? false) || (user?.roleLevel ?? 0) >= 20)
            IconButton(
              icon: const Icon(Icons.notification_add_outlined, color: AppColors.gold),
              tooltip: isEn ? 'Send Test Notification to This Device' : 'የሙከራ ማሳወቂያ ወደዚህ ስልክ ላክ',
              onPressed: () => _confirmAndSendTestNotification(isEn),
            ),
          IconButton(
            icon: const Icon(Icons.today_rounded, color: AppColors.gold),
            tooltip: isEn ? 'Today' : 'ዛሬ',
            onPressed: _jumpToToday,
          ),
          sinksarAsync.maybeWhen(
            data: (day) => IconButton(
              icon: const Icon(Icons.share_rounded, color: AppColors.gold),
              tooltip: isEn ? 'Share' : 'አጋራ',
              onPressed: () => _share(day, isEn),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date Navigation Bar
            _buildDateBar(context, isEn),

            // Content
            Expanded(
              child: RefreshIndicator(
                color: AppColors.gold,
                onRefresh: () async {
                  ref.invalidate(sinksarDateProvider(_currentDateIso));
                  await ref.read(sinksarDateProvider(_currentDateIso).future);
                },
                child: sinksarAsync.when(
                  data: (day) => _buildContent(context, day, isEn),
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                  error: (e, _) => ErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(sinksarDateProvider(_currentDateIso)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBar(BuildContext context, bool isEn) {
    final eth = EthiopianDate.fromGregorian(_selectedDate);
    const monthsAm = [
      '', 'መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሣሥ', 'ጥር', 'የካቲት',
      'መጋቢት', 'ሚያዝያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜ'
    ];
    final mName = eth.month >= 1 && eth.month <= 13 ? monthsAm[eth.month] : '';
    final dateLabel = '$mName ${eth.day}፣ ${eth.year} ዓ.ም';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            onPressed: _previousDay,
            tooltip: isEn ? 'Previous Day' : 'ያለፈው ቀን',
          ),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.maroon.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text(
                    dateLabel,
                    style: context.sans(14, weight: FontWeight.bold, color: AppColors.goldDark),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            onPressed: _nextDay,
            tooltip: isEn ? 'Next Day' : 'ቀጣይ ቀን',
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, SinksarDay day, bool isEn) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // Top Header Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.maroon.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars_rounded, color: AppColors.gold, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day.formattedFull,
                          style: context.sans(15, weight: FontWeight.bold, color: AppColors.goldDark),
                        ),
                        Text(
                          '${day.gregorianDate} · ${day.weekdayEn}',
                          style: context.sans(11, color: context.palette.muted),
                        ),
                      ],
                    ),
                  ),
                  if (day.isFasting)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.maroon,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        day.fastingReason ?? (isEn ? 'Fasting' : 'የጾም ቀን'),
                        style: context.sans(11, color: Colors.white, weight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                day.featuredTitle,
                style: context.serif(20, weight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Source attribution banner
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: context.palette.fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_outlined, size: 16, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEn
                      ? 'Source: Synaxarium (Metsihafe Sinksar) — Orthodox Church Tradition'
                      : 'ምንጭ፦ መጽሐፈ ስንክሳር (የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተ ክርስቲያን ስርዓትና ትውፊት)',
                  style: context.sans(11, color: context.palette.muted),
                ),
              ),
            ],
          ),
        ),

        // Daily summary section if present
        if (day.summary != null && day.summary!.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book_outlined, size: 16, color: AppColors.goldDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isEn ? 'Daily Commemoration Summary' : 'የዕለቱ ማጠቃለያ',
                        style: context.sans(13, weight: FontWeight.bold, color: AppColors.goldDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(day.summary!, style: context.sans(13, height: 1.5)),
              ],
            ),
          ),
        ],

        // Section 1: Annual Feasts (ዓመታዊ በዓላት)
        if (day.annualFeasts.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: isEn ? 'Annual Commemorations' : 'ዓመታዊ የቅዱሳን በዓላት',
            icon: Icons.celebration_rounded,
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: day.annualFeasts.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.gold.withValues(alpha: 0.15)),
              itemBuilder: (context, i) {
                final feast = day.annualFeasts[i];
                final hasDesc = feast.sourceText.isNotEmpty &&
                    feast.sourceText != feast.title &&
                    !feast.sourceText.startsWith('፩. ${feast.title}');
                return ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                    child: Text(
                      '${i + 1}',
                      style: context.sans(12, weight: FontWeight.bold, color: AppColors.goldDark),
                    ),
                  ),
                  title: Text(
                    feast.title,
                    style: context.sans(15, weight: FontWeight.w600),
                  ),
                  subtitle: hasDesc
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(feast.sourceText, style: context.sans(13, color: context.palette.muted)),
                        )
                      : null,
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Section 2: Monthly Feasts (ወርኀዊ በዓላት)
        if (day.monthlyFeasts.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: isEn ? 'Monthly Commemorations' : 'ወርኀዊ የቅዱሳን በዓላት',
            icon: Icons.event_note_rounded,
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: day.monthlyFeasts.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.gold.withValues(alpha: 0.15)),
              itemBuilder: (context, i) {
                final feast = day.monthlyFeasts[i];
                final hasDesc = feast.sourceText.isNotEmpty &&
                    feast.sourceText != feast.title &&
                    !feast.sourceText.startsWith('፩. ${feast.title}');
                return ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.maroon.withValues(alpha: 0.12),
                    child: Text(
                      '${i + 1}',
                      style: context.sans(12, weight: FontWeight.bold, color: AppColors.maroon),
                    ),
                  ),
                  title: Text(
                    feast.title,
                    style: context.sans(15, weight: FontWeight.w600),
                  ),
                  subtitle: hasDesc
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(feast.sourceText, style: context.sans(13, color: context.palette.muted)),
                        )
                      : null,
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Section 3: Full Narratives (ሙሉ ገድላትና ድርሳናት)
        _buildSectionHeader(
          context,
          title: isEn ? 'Full Sinksar Narratives' : 'የዕለቱ ገድላትና ድርሳናት',
          icon: Icons.menu_book_rounded,
        ),
        const SizedBox(height: 8),
        if (day.hasNarratives) ...[
          for (final n in day.narratives) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title.replaceAll('dit*', '').replaceAll('d*', ''), style: context.serif(18, weight: FontWeight.bold, color: AppColors.goldDark)),
                  if (n.source != null) ...[
                    const SizedBox(height: 4),
                    Text('ምንጭ፦ ${n.source}', style: context.sans(12, color: AppColors.faint)),
                  ],
                  const Divider(height: 16),
                  Text(
                    n.body.replaceAll('dit*', '').replaceAll('d*', ''),
                    style: context.serif(15, height: 1.8),
                  ),
                ],
              ),
            ),
          ]
        ] else ...[
          // Honest indicator distinguishing daily calendar from full narratives
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                const Icon(Icons.info_outline_rounded, size: 36, color: AppColors.gold),
                const SizedBox(height: 10),
                Text(
                  isEn ? 'Daily Commemoration Summary' : 'የዕለቱ የቅዱሳን መታሰቢያ ዝርዝር',
                  style: context.sans(15, weight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  isEn
                      ? 'The complete authorized Amharic narrative text for this day is currently pending church publication rights. All verified annual and monthly commemorations are listed above.'
                      : 'የተሟላው የገድላትና ድርሳናት ጽሑፍ በቅርቡ በፈቃድ የሚካተት ሲሆን፣ ለዕለቱ የተረጋገጡት ዓመታዊና ወርኀዊ መታሰቢያዎች ከላይ ተዘርዝረዋል።',
                  textAlign: TextAlign.center,
                  style: context.sans(13, color: AppColors.faint, height: 1.6),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, {required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.gold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: context.serif(17, weight: FontWeight.bold, color: AppColors.goldDark),
          ),
        ),
      ],
    );
  }
}
