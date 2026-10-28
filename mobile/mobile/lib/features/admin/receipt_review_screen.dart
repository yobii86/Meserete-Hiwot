import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../members/department_participation.dart' show periodLabel;
import 'admin_widgets.dart';

/// Admin screen for authorized financial officers to review member contribution receipts.
class ReceiptReviewAdminScreen extends ConsumerStatefulWidget {
  const ReceiptReviewAdminScreen({super.key});

  @override
  ConsumerState<ReceiptReviewAdminScreen> createState() => _ReceiptReviewAdminScreenState();
}

class _ReceiptReviewAdminScreenState extends ConsumerState<ReceiptReviewAdminScreen> {
  final _ctrl = PagedListController<Json>();
  String? _status = 'submitted';
  String _q = '';

  Future<void> _reviewReceipt(Json row, String decision) async {
    final l = context.l10n;
    final isApprove = decision == 'approved';
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove
            ? (l.isEn ? 'Approve Contribution Receipt' : 'የመዋጮ ደረሰኝ አጽድቅ')
            : (l.isEn ? 'Reject Contribution Receipt' : 'የመዋጮ ደረሰኝ ውድቅ አድርግ')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row['full_name'] ?? 'Member'} · ${asIntOr(row['months'], 1)} ${l.isEn ? "months" : "ወራት"}',
              style: ctx.sans(13, weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              isApprove
                  ? (l.isEn
                      ? 'Approving will record verified payments for the selected months and notify the member.'
                      : 'ማጽደቅ ለተመረጡት ወራት የተረጋገጠ ክፍያ ይመዘግባል እንዲሁም ለአባሉ ማሳወቂያ ይልካል።')
                  : (l.isEn
                      ? 'Please provide a reason for rejection so the member can correct it.'
                      : 'አባሉ እንዲያስተካክለው እባክዎ ውድቅ የተደረገበትን ምክንያት ይግለጹ።'),
              style: ctx.sans(12, color: ctx.palette.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: isApprove
                    ? (l.isEn ? 'Verification Note (Optional)' : 'የማረጋገጫ ማስታወሻ (አማራጭ)')
                    : (l.isEn ? 'Rejection Reason (Required)' : 'ውድቅ የተደረገበት ምክንያት (ግዴታ)'),
                hintText: isApprove
                    ? (l.isEn ? 'e.g. Verified on Telebirr statement' : 'ምሳሌ፡ በቴሌብር ስቴትመንት ተረጋግጧል')
                    : (l.isEn ? 'e.g. Reference number not found' : 'ምሳሌ፡ የሪፈረንስ ቁጥር አልተገኘም'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isApprove ? const Color(0xFF2E7D32) : AppColors.danger,
            ),
            onPressed: () {
              if (!isApprove && noteCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: Text(isApprove ? (l.isEn ? 'Approve' : 'አጽድቅ') : (l.isEn ? 'Reject' : 'ውድቅ አድርግ')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = ref.read(orgRepositoryProvider);
    await runWithProgress(
      context,
      () => repo.reviewContributionReceipt(
        asIntOr(row['id']),
        status: decision,
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      ),
      success: isApprove
          ? (l.isEn ? 'Receipt approved and payment verified!' : 'ደረሰኙ ጸድቋል፣ ክፍያውም ተረጋግጧል!')
          : (l.isEn ? 'Receipt marked as rejected.' : 'ደረሰኙ ውድቅ ተደርጓል።'),
    );

    _ctrl.refresh();
  }

  void _viewReceiptFile(Json row) {
    final url = asStr(row['receipt_url']);
    if (url == null || url.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(row['full_name'] ?? 'Receipt'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  errorBuilder: (_, _, _) => Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(ctx.l10n.isEn ? 'Cannot load receipt file preview.' : 'የደረሰኙን ቅድመ-እይታ መጫን አልተቻለም።'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final repo = ref.read(orgRepositoryProvider);

    return AdminScaffold(
      title: l.isEn ? 'Contribution Receipts' : 'የመዋጮ ደረሰኞች ግምገማ',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchBox(onChanged: (v) {
              setState(() => _q = v);
              _ctrl.refresh();
            }),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(l.isEn ? 'All' : 'ሁሉም'),
                  selected: _status == null,
                  onSelected: (_) {
                    setState(() => _status = null);
                    _ctrl.refresh();
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(l.isEn ? 'Submitted' : 'የገቡ'),
                  selected: _status == 'submitted',
                  onSelected: (_) {
                    setState(() => _status = 'submitted');
                    _ctrl.refresh();
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(l.isEn ? 'Approved' : 'የጸደቁ'),
                  selected: _status == 'approved',
                  onSelected: (_) {
                    setState(() => _status = 'approved');
                    _ctrl.refresh();
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(l.isEn ? 'Rejected' : 'ውድቅ የተደረጉ'),
                  selected: _status == 'rejected',
                  onSelected: (_) {
                    setState(() => _status = 'rejected');
                    _ctrl.refresh();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 12),
          Expanded(
            child: PagedListView<Json>(
              controller: _ctrl,
              fetch: (page) => repo.adminContributionReceipts(
                status: _status,
                q: _q.isEmpty ? null : _q,
                page: page,
              ),
              emptyMessage: l.noResults,
              itemBuilder: (ctx, row, _) {
                final st = asStr(row['status']) ?? 'submitted';
                final isPending = st == 'submitted' || st == 'under_review';
                final expectedAmt = asDouble(row['expected_amount'], 0);
                final submittedAmt = asDouble(row['submitted_amount'], 0);
                final currency = asStr(row['currency']) ?? 'ETB';
                final hasDiscrepancy = (expectedAmt - submittedAmt).abs() > 0.01;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${row['full_name'] ?? 'Member'}',
                                style: ctx.sans(14, weight: FontWeight.w700),
                              ),
                            ),
                            _statusBadge(ctx, st),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          asIntOr(row['months'], 1) == 1
                              ? periodLabel(ctx, '${row['period']}')
                              : '${periodLabel(ctx, '${row['period']}')} – ${periodLabel(ctx, '${row['coverage_end']}')} (${row['months']} ${l.isEn ? "months" : "ወራት"})',
                          style: ctx.sans(12, color: ctx.palette.muted),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${l.isEn ? "Expected: " : "የሚጠበቀው፡ "}${f.money(expectedAmt, currency)}',
                                  style: ctx.sans(12, color: ctx.palette.muted),
                                ),
                                Text(
                                  '${l.isEn ? "Submitted: " : "የገባው፡ "}${f.money(submittedAmt, currency)}',
                                  style: ctx.sans(
                                    13,
                                    weight: FontWeight.w700,
                                    color: hasDiscrepancy ? AppColors.danger : AppColors.maroon,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${row['method'] ?? 'cash'} · ${row['paid_on'] ?? ''}',
                                  style: ctx.sans(11, color: ctx.palette.muted),
                                ),
                                if (asStr(row['reference']) != null)
                                  Text(
                                    'Ref: ${row['reference']}',
                                    style: ctx.sans(11, weight: FontWeight.w600),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        if (hasDiscrepancy)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              l.isEn ? '⚠️ Amount discrepancy detected.' : '⚠️ የገንዘብ መጠን ልዩነት አለ።',
                              style: ctx.sans(11, color: AppColors.danger, weight: FontWeight.w600),
                            ),
                          ),
                        if (asStr(row['member_note']) != null && asStr(row['member_note'])!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${l.isEn ? "Member Note: " : "የአባል ማስታወሻ፡ "}${row['member_note']}',
                              style: ctx.sans(11, color: ctx.palette.muted),
                            ),
                          ),
                        if (asStr(row['review_note']) != null && asStr(row['review_note'])!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${l.isEn ? "Review note: " : "የግምገማ ማስታወሻ፡ "}${row['review_note']}',
                              style: ctx.sans(11, color: ctx.palette.text, weight: FontWeight.w500),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.image_outlined, size: 16),
                              label: Text(l.isEn ? 'Receipt' : 'ደረሰኝ'),
                              onPressed: () => _viewReceiptFile(row),
                            ),
                            if (isPending) ...[
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                                onPressed: () => _reviewReceipt(row, 'rejected'),
                                child: Text(l.isEn ? 'Reject' : 'ውድቅ'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                                onPressed: () => _reviewReceipt(row, 'approved'),
                                child: Text(l.isEn ? 'Approve' : 'አጽድቅ'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(BuildContext context, String status) {
    final l = context.l10n;
    final (color, label) = switch (status) {
      'approved' => (const Color(0xFF2E7D32), l.isEn ? 'Approved' : 'ጸድቋል'),
      'rejected' => (AppColors.danger, l.isEn ? 'Rejected' : 'ተቀባይነት አላገኘም'),
      'under_review' => (Colors.blue.shade700, l.isEn ? 'Under Review' : 'በግምገማ ላይ'),
      _ => (Colors.orange.shade800, l.isEn ? 'Submitted' : 'ተልኳል'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: context.sans(11, weight: FontWeight.w700, color: color),
      ),
    );
  }
}
