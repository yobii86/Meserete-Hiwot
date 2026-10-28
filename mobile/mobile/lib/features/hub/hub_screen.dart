import 'dart:async';
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/offline_pack.dart';
import '../../core/providers.dart';
import '../../core/l10n/l10n.dart';
import '../choir/eligibility_screen.dart' show paymentStatusText, paymentStatusColor;
import '../members/department_participation.dart' show periodLabel;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/qr.dart';
import '../../widgets/states.dart';
import '../contributions/submit_receipt_dialog.dart';
import '../../app/chrome.dart';
import '../auth/session.dart';
import '../home/home_screen.dart' show BannerCarousel;
import '../../models/content.dart' show Banner;
import '../guidance/contextual_help_sheet.dart';
import '../guidance/tour_engine.dart';
import '../sinksar/holy_day_banner.dart';
import '../../app/router.dart' show showModuleDisabledSnackbar;

/// Active featured banners (advertisements / events) for the home page.
final hubBannersProvider = FutureProvider.autoDispose<List<Banner>>((ref) => ref.watch(contentRepositoryProvider).banners());

/// Home: "Hello, [name]", the active featured banners, then the two sections — ትምህርት and
/// መዝሙር. The shared top bar (logo, search, notifications, theme) comes from the app shell.
class HubScreen extends ConsumerStatefulWidget {
  const HubScreen({super.key});

  @override
  ConsumerState<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends ConsumerState<HubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        TourController.instance.startTour(context, 'welcome_tour', ref: ref, force: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final user = ref.watch(currentUserProvider);
    return PatternScaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          // Two tall cards that share the screen height (with sensible bounds on small / large phones).
          final banners = ref.watch(hubBannersProvider).value ?? const <Banner>[];
          final cardHeight = ((box.maxHeight - (banners.isEmpty ? 110 : 300)) / 2).clamp(140.0, 240.0); // room for the banners
          return ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 24), children: [
            Row(
              key: TourKeys.hubHeader,
              children: [
                if (user != null)
                  Expanded(
                    child: Text(l.hubGreeting(user.fullName.split(' ').first), style: context.serif(20)),
                  ),
                const ContextualHelpButton(screenRoute: '/hub'),
              ],
            ),
            // Right after the greeting: the active featured banners (promotions & approved event banners).
            if (banners.isNotEmpty) ...[
              const SizedBox(height: 12),
              BannerCarousel(key: const ValueKey('shared.home.promotion.carousel'), banners: banners),
            ],
            const SizedBox(height: 14),
            const HolyDayBanner(margin: EdgeInsets.only(bottom: 14), padding: EdgeInsets.only(bottom: 14)),

            // Primary Module Choice: Education
            if (user?.moduleAccess.education ?? true)
              _BigCard(
                key: const ValueKey('shared.home.module_selector.education'),
                title: l.hubEducation,
                subtitle: l.hubEducationSub,
                icon: const EduIcon(size: 48),
                watermark: const Opacity(opacity: 0.16, child: EduIcon(size: 170)),
                color: const Color(0xFF1F5F8B),
                height: cardHeight,
                onTap: () {
                  if (!(user?.moduleAccess.education ?? true)) {
                    showModuleDisabledSnackbar();
                    return;
                  }
                  context.go('/edu');
                },
              ),

            // Primary Module Choice: Mezmur
            if (user?.moduleAccess.mezmur ?? true)
              _BigCard(
                key: const ValueKey('shared.home.module_selector.mezmur'),
                title: l.hubMezmur,
                subtitle: l.hubMezmurSub,
                icon: const KeberoIcon(color: Colors.white, size: 42, filled: true),
                watermark: KeberoIcon(color: Colors.white.withValues(alpha: 0.12), size: 170, filled: true),
                color: AppColors.maroon,
                height: cardHeight,
                onTap: () {
                  if (!(user?.moduleAccess.mezmur ?? true)) {
                    showModuleDisabledSnackbar();
                    return;
                  }
                  context.go('/home');
                },
              ),
          ]);
        },
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  const _BigCard({super.key, required this.title, required this.subtitle, required this.icon, required this.watermark, required this.color, required this.onTap, this.height = 150});
  final String title;
  final String subtitle;
  final Widget icon;
  final Widget watermark;
  final Color color;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        elevation: 6,
        shadowColor: color.withValues(alpha: 0.5),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Stack(children: [
              Positioned(right: -18, bottom: -24, child: watermark),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(18)),
                    child: Center(child: icon),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: context.serif(26, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.sans(12, color: Colors.white.withValues(alpha: 0.85))),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ስለ እኔ
// =============================================================================
/// The member's own card + QR. Online it is fetched (and saved in the phone's database); offline —
/// or when the server cannot be reached — the saved copy is shown, so the QR always appears.
final myCardProvider = FutureProvider.autoDispose<Json>((ref) async {
  final pack = ref.watch(offlinePackProvider);
  try {
    final card = await ref.watch(orgRepositoryProvider).myCard();
    unawaited(ref.read(localDbProvider).putCache('pack:my_card', card));
    return card;
  } catch (e) {
    final saved = await pack.myCard();
    if (saved != null) return saved;
    rethrow;
  }
});
final myPaymentsProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(orgRepositoryProvider).myPayments());
final myReceiptsProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(orgRepositoryProvider).myReceipts());

/// Scan a member's QR and show their card (admins, teachers, attendance takers).
Future<void> scanAndShowMember(BuildContext context, WidgetRef ref) async {
  final uuid = await scanMemberQr(context);
  if (uuid == null || !context.mounted) return;
  final card = await runWithProgress(context, () => ref.read(orgRepositoryProvider).member(uuid));
  if (card == null || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: MemberCard(card: card, showQr: false))),
  );
}


/// The current Ethiopian year's payment status: "all paid" only when the 12 months are covered,
/// otherwise how many months (and which) are paid.
String paymentYearSummary(AppLocalizations l, Json year) {
  final y = '${year['year'] ?? ''}';
  final paid = asIntOr(year['months_paid']);
  if (year['exempt'] == true) return l.paymentExempt;
  if (year['full'] == true) return l.paymentsYearFull(y);
  if (paid == 0) return l.paymentsYearNone(y);
  return l.paymentsYearPartial(y, '$paid', '${12 - paid}');
}

String paymentYearMonths(Formatters f, Json year) =>
    asJsonList(year['paid_months']).isEmpty ? '' : (year['paid_months'] as List).map((m) => f.monthName(asIntOr(m))).join(', ');

class MyPaymentsScreen extends ConsumerWidget {
  const MyPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final myPayAsync = ref.watch(myPaymentsProvider);
    final policy = myPayAsync.value != null ? asJson(myPayAsync.value!['policy']) : <String, dynamic>{};
    final defaultRate = asDouble(policy['default_rate'] ?? 50);
    final currency = asStr(policy['currency']) ?? 'ETB';

    return PatternScaffold(
      appBar: AppBar(
        title: Text(l.monthlyPayments),
        actions: const [ContextualHelpButton(screenRoute: '/settings/payments')],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.maroon,
        icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
        label: Text(l.isEn ? 'Submit Receipt' : 'ደረሰኝ አስገባ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () async {
          final ok = await showSubmitContributionReceiptDialog(context);
          if (ok == true) {
            ref.invalidate(myPaymentsProvider);
          }
        },
      ),
      body: AsyncView(
        value: myPayAsync,
        onRetry: () => ref.invalidate(myPaymentsProvider),
        data: (d) {
          final months = asJsonList(d['months']);
          final pol = asJson(d['policy']);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
            MaroonCard(
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.totalPaid, style: context.sans(12, color: AppColors.goldLight)),
                    Text(f.money(asDouble(d['total_paid']), asStr(pol['currency']) ?? 'ETB'), style: context.serif(22, color: Colors.white)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(l.paidMonths(asIntOr(d['paid_count'])), style: context.sans(12, color: Colors.white)),
                  Text(l.paymentsUnpaid(asIntOr(d['unpaid_count'])), style: context.sans(12, color: AppColors.goldLight)),
                ]),
              ]),
            ),
            if (d['year'] is Map && d['exempt'] != true)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: AppCard(
                  key: const ValueKey('payments-year'),
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(paymentYearSummary(l, asJson(d['year'])), style: context.sans(14, weight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: asIntOr(asJson(d['year'])['months_paid']) / 12, color: AppColors.gold, minHeight: 6, borderRadius: BorderRadius.circular(4)),
                    if (paymentYearMonths(f, asJson(d['year'])).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(l.paymentsYearPaidList(paymentYearMonths(f, asJson(d['year']))), style: context.sans(12, color: context.palette.muted)),
                    ],
                  ]),
                ),
              ),

            // Submitted receipts under review section
            ref.watch(myReceiptsProvider).when(
                  data: (receipts) {
                    if (receipts.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.isEn ? 'Submitted Receipts' : 'የተላኩ ደረሰኞች', style: context.sans(14, weight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          for (final r in receipts)
                            AppCard(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${r['months']} ${l.isEn ? 'Month(s)' : 'ወራት'} (${f.money(asDouble(r['amount']), asStr(r['currency']) ?? 'ETB')})',
                                          style: context.sans(13.5, weight: FontWeight.w700),
                                        ),
                                      ),
                                      if (r['status'] == 'pending')
                                        Pill(l.isEn ? 'Pending Review' : 'በግምገማ ላይ', color: AppColors.goldDark, icon: Icons.schedule_rounded)
                                      else if (r['status'] == 'approved')
                                        Pill(l.isEn ? 'Approved' : 'ጸድቋል', color: AppColors.success, icon: Icons.verified_rounded)
                                      else
                                        Pill(l.isEn ? 'Rejected' : 'ውድቅ ተደርጓል', color: AppColors.danger, icon: Icons.cancel_outlined),
                                    ],
                                  ),
                                  if (r['transaction_reference'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text('${l.paymentReference}: ${r['transaction_reference']}', style: context.sans(12, color: context.palette.muted)),
                                    ),
                                  if (r['created_at'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(f.dateTime(asDate(r['created_at'])), style: context.sans(11, color: context.palette.muted)),
                                    ),
                                  if (r['status'] == 'rejected' && r['rejection_reason'] != null)
                                    Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.danger),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${l.isEn ? 'Rejection reason:' : 'የውድቅ ምክንያት:'} ${r['rejection_reason']}',
                                              style: context.sans(12, color: AppColors.danger, weight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (r['receipt_url'] != null) ...[
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () => showDialog<void>(
                                        context: context,
                                        builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(asStr(r['receipt_url'])!))),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.image_outlined, size: 16, color: AppColors.goldDark),
                                          const SizedBox(width: 6),
                                          Text(l.isEn ? 'View Receipt Image' : 'ደረሰኙን ይመልከቱ', style: context.sans(12, color: AppColors.goldDark, weight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

            const SizedBox(height: 12),
            if (months.isEmpty) EmptyView(message: l.noPayments, icon: Icons.payments_outlined),
            if (d['exempt'] == true) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.paymentExempt, style: context.sans(13, color: context.palette.muted))),
            if (months.isNotEmpty)
              AppCard(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Column(children: [
                  // Month (Ethiopian) · Required · Paid · Status
                  Row(children: [
                    Expanded(flex: 3, child: Text(l.month, style: context.sans(12, weight: FontWeight.w700, color: context.palette.muted))),
                    Expanded(flex: 2, child: Text(l.required, style: context.sans(12, weight: FontWeight.w700, color: context.palette.muted))),
                    Expanded(flex: 2, child: Text(l.paid, style: context.sans(12, weight: FontWeight.w700, color: context.palette.muted))),
                    Expanded(flex: 2, child: Text(l.status, style: context.sans(12, weight: FontWeight.w700, color: context.palette.muted))),
                  ]),
                  const Divider(height: 12),
                  for (final m in months)
                    InkWell(
                      onTap: asStr(asJson(m['payment'])['receipt_url']) == null
                          ? null
                          : () => showDialog<void>(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(asStr(asJson(m['payment'])['receipt_url'])!)))),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(children: [
                          Expanded(flex: 3, child: Text(periodLabel(context, '${m['period']}'), style: context.sans(13))),
                          Expanded(flex: 2, child: Text(m['required'] == null ? '—' : f.money(asDouble(m['required']), asStr(pol['currency']) ?? 'ETB'), style: context.sans(12))),
                          Expanded(flex: 2, child: Text(f.money(asDouble(m['paid']), asStr(pol['currency']) ?? 'ETB'), style: context.sans(12))),
                          Expanded(flex: 2, child: Text(paymentStatusText(l, '${m['status']}'), style: context.sans(12, weight: FontWeight.w600, color: paymentStatusColor('${m['status']}')))),
                        ]),
                      ),
                    ),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}

Future<void> _submitReceiptDialog(BuildContext context, WidgetRef ref, double rate, String currency) async {
  final l = context.l10n;
  final f = Formatters(l, Localizations.localeOf(context).languageCode);
  int months = 1;
  final refCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  XFile? pickedFile;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final totalAmount = months * rate;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.isEn ? 'Submit Contribution Receipt' : 'የመዋጮ ደረሰኝ አስገባ', style: ctx.serif(18, weight: FontWeight.w700)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(l.isEn ? 'Covered Months:' : 'የሚከፈልባቸው ወራት:', style: ctx.sans(13, weight: FontWeight.w600)),
                    const Spacer(),
                    DropdownButton<int>(
                      value: months,
                      items: [
                        for (int m = 1; m <= 12; m++)
                          DropdownMenuItem(value: m, child: Text('$m ${l.isEn ? (m == 1 ? 'Month' : 'Months') : 'ወር'}')),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => months = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.maroon.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.maroon.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Text(l.isEn ? 'Calculated Total:' : 'አጠቃላይ ክፍያ:', style: ctx.sans(13, weight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        f.money(totalAmount, currency),
                        style: ctx.serif(18, color: AppColors.maroon, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: InputDecoration(
                    labelText: l.paymentReference,
                    hintText: 'e.g. TXN-12345678',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: l.isEn ? 'Note (Optional)' : 'ተጨማሪ ማስታወሻ (አማራጭ)',
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final img = await picker.pickImage(source: ImageSource.gallery);
                    if (img != null) {
                      setModalState(() => pickedFile = img);
                    }
                  },
                  icon: Icon(pickedFile != null ? Icons.check_circle_rounded : Icons.add_photo_alternate_outlined),
                  label: Text(pickedFile != null ? pickedFile!.name : (l.isEn ? 'Select Receipt Image' : 'ደረሰኝ ምረጥ (ፎቶ / ምስል)')),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: pickedFile == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          final ok = await runWithProgress(
                            context,
                            () => ref.read(orgRepositoryProvider).submitReceipt(
                                  filePath: pickedFile!.path,
                                  months: months,
                                  amount: totalAmount,
                                  note: [
                                    if (refCtrl.text.trim().isNotEmpty) 'Ref: ${refCtrl.text.trim()}',
                                    if (noteCtrl.text.trim().isNotEmpty) noteCtrl.text.trim(),
                                  ].join(' - '),
                                ),
                            success: l.isEn ? 'Receipt submitted for review!' : 'ደረሰኙ ለግምገማ በተሳካ ሁኔታ ቀርቧል!',
                          );
                          if (ok != null) {
                            ref.invalidate(myPaymentsProvider);
                            ref.invalidate(myReceiptsProvider);
                          }
                        },
                  child: Text(l.isEn ? 'Submit for Review' : 'ለግምገማ አስገባ'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

String paymentMethodLabel(AppLocalizations l, String? m) => switch (m) {
      'bank' => l.methodBank,
      'telebirr' => l.methodTelebirr,
      'other' => l.methodOther,
      _ => l.methodCash,
    };
