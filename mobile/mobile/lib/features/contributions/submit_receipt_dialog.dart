import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/typed_picker.dart';
import '../members/department_participation.dart' show ethPeriod, periodLabel;

/// Shows the interactive modal to submit a monthly contribution receipt.
Future<bool?> showSubmitContributionReceiptDialog(BuildContext context, {String? defaultPeriod}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SubmitContributionReceiptSheet(defaultPeriod: defaultPeriod),
    ),
  );
}

class SubmitContributionReceiptSheet extends ConsumerStatefulWidget {
  const SubmitContributionReceiptSheet({super.key, this.defaultPeriod});
  final String? defaultPeriod;

  @override
  ConsumerState<SubmitContributionReceiptSheet> createState() => _SubmitContributionReceiptSheetState();
}

class _SubmitContributionReceiptSheetState extends ConsumerState<SubmitContributionReceiptSheet> {
  late String _period;
  int _months = 1;
  String _method = 'telebirr';
  DateTime _paidOn = DateTime.now();
  final _refCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  PickedFile? _receiptFile;
  Json? _calcResult;
  bool _calculating = false;
  bool _submitting = false;
  String? _calcError;

  @override
  void initState() {
    super.initState();
    _period = widget.defaultPeriod ?? ethPeriod(DateTime.now());
    _fetchCalculation();
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _noteCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCalculation() async {
    setState(() {
      _calculating = true;
      _calcError = null;
    });

    try {
      final repo = ref.read(orgRepositoryProvider);
      final res = await repo.calculateContributionReceipt(period: _period, months: _months);
      if (mounted) {
        setState(() {
          _calcResult = res;
          final exp = asDouble(res['expected_amount'], 0);
          if (_amountCtrl.text.isEmpty || _amountCtrl.text == '0') {
            _amountCtrl.text = exp > 0 ? '$exp' : '';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _calcError = '$e';
        });
      }
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  Future<void> _pickReceipt() async {
    final picked = await pickTypedFile(context, kinds: {PickKind.image, PickKind.document});
    if (picked != null && mounted) {
      setState(() => _receiptFile = picked);
    }
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (_receiptFile == null) {
      await showInfo(context, l.isEn ? 'Please attach a payment receipt file or image.' : 'እባክዎ የክፍያ ደረሰኝ ምስል ወይም ሰነድ ያያይዙ።');
      return;
    }

    final enteredAmt = double.tryParse(_amountCtrl.text.trim()) ?? asDouble(_calcResult?['expected_amount'], 0);
    if (enteredAmt <= 0) {
      await showInfo(context, l.isEn ? 'Please enter a valid payment amount.' : 'እባክዎ ትክክለኛ የክፍያ መጠን ያስገቡ።');
      return;
    }

    setState(() => _submitting = true);

    try {
      final repo = ref.read(orgRepositoryProvider);
      await repo.submitContributionReceipt(
        filePath: _receiptFile!.path,
        period: _period,
        months: _months,
        submittedAmount: enteredAmt,
        method: _method,
        paidOn: Formatters.isoDate(_paidOn),
        reference: _refCtrl.text.trim(),
        note: _noteCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.isEn ? 'Receipt submitted successfully for review!' : 'ደረሰኙ ለግምገማ በተሳካ ሁኔታ ተልኳል!'),
            backgroundColor: AppColors.maroon,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, e);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);

    final expectedAmount = asDouble(_calcResult?['expected_amount'], 0);
    final currency = asStr(_calcResult?['currency']) ?? 'ETB';
    final coverageEnd = asStr(_calcResult?['coverage_end']) ?? _period;

    // Generate recent and upcoming Ethiopian periods
    final currentEth = EthiopianDate.fromGregorian(DateTime.now());
    final periods = <String>[];
    for (var y = currentEth.year - 1; y <= currentEth.year + 1; y++) {
      for (var m = 1; m <= 12; m++) {
        periods.add('$y-${m.toString().padLeft(2, '0')}');
      }
    }
    if (!periods.contains(_period)) periods.insert(0, _period);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.isEn ? 'Submit Contribution Receipt' : 'የወርሃዊ መዋጮ ደረሰኝ ማስገቢያ',
                  style: context.serif(18, weight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            const Divider(height: 16),

            // Starting Month and Months Count
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _period,
                    decoration: InputDecoration(
                      labelText: l.isEn ? 'Starting Month' : 'መነሻ ወር',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      for (final per in periods)
                        DropdownMenuItem(
                          value: per,
                          child: Text(periodLabel(context, per)),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null && v != _period) {
                        setState(() => _period = v);
                        _fetchCalculation();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    initialValue: _months,
                    decoration: InputDecoration(
                      labelText: l.isEn ? 'Number of Months' : 'የወራት ብዛት',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(
                          value: m,
                          child: Text(l.monthsCount('$m')),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null && v != _months) {
                        setState(() => _months = v);
                        _fetchCalculation();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Coverage calculation banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l.isEn ? 'Coverage:' : 'የሽፋን ጊዜ፡',
                        style: context.sans(12, weight: FontWeight.w600, color: p.muted),
                      ),
                      if (_calculating)
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        Text(
                          _months == 1
                              ? periodLabel(context, _period)
                              : '${periodLabel(context, _period)} – ${periodLabel(context, coverageEnd)}',
                          style: context.sans(13, weight: FontWeight.w700),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l.isEn ? 'Expected Amount:' : 'የሚጠበቀው መጠን፡',
                        style: context.sans(12, weight: FontWeight.w600, color: p.muted),
                      ),
                      Text(
                        f.money(expectedAmount, currency),
                        style: context.serif(18, weight: FontWeight.w700, color: AppColors.maroon),
                      ),
                    ],
                  ),
                  if (_calcError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _calcError!,
                        style: context.sans(11, color: AppColors.danger),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Submitted Amount & Payment Method
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l.isEn ? 'Paid Amount ($currency)' : 'የተከፈለው መጠን ($currency)',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _method,
                    decoration: InputDecoration(
                      labelText: l.isEn ? 'Method' : 'የክፍያ ዘዴ',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      DropdownMenuItem(value: 'telebirr', child: Text(l.methodTelebirr)),
                      DropdownMenuItem(value: 'bank', child: Text(l.methodBank)),
                      DropdownMenuItem(value: 'cash', child: Text(l.methodCash)),
                      DropdownMenuItem(value: 'other', child: Text(l.methodOther)),
                    ],
                    onChanged: (v) => setState(() => _method = v ?? 'telebirr'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Transaction Reference & Payment Date
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _refCtrl,
                    decoration: InputDecoration(
                      labelText: l.isEn ? 'Transaction / Ref No.' : 'የማረጋገጫ / ሪፈረንስ ቁጥር',
                      hintText: 'e.g. TB12345678',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _paidOn,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) setState(() => _paidOn = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l.isEn ? 'Payment Date' : 'የተከፈለበት ቀን',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      child: Text(
                        Formatters.isoDate(_paidOn),
                        style: context.sans(13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Note field
            TextFormField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l.isEn ? 'Note (Optional)' : 'ተጨማሪ ማስታወሻ (አማራጭ)',
                hintText: l.isEn ? 'Any details for the financial reviewer...' : 'ለፋይናንስ አስተዳዳሪው የሚሰጥ ማስታወሻ...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),

            // Receipt File Attachment Card
            InkWell(
              onTap: _pickReceipt,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: _receiptFile == null ? p.card : AppColors.maroon.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _receiptFile == null ? p.muted.withValues(alpha: 0.3) : AppColors.maroon,
                    width: _receiptFile == null ? 1 : 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _receiptFile == null ? Icons.upload_file_rounded : Icons.check_circle_rounded,
                      color: _receiptFile == null ? p.muted : AppColors.maroon,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _receiptFile == null
                                ? (l.isEn ? 'Attach Payment Receipt (Image or PDF)' : 'የክፍያ ደረሰኝ ያያይዙ (ምስል ወይም ፒዲኤፍ)')
                                : _receiptFile!.name,
                            style: context.sans(
                              13,
                              weight: _receiptFile == null ? FontWeight.w500 : FontWeight.w700,
                              color: _receiptFile == null ? p.text : AppColors.maroon,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _receiptFile == null
                                ? (l.isEn ? 'Click to select from gallery, camera, or files' : 'ከጋለሪ፣ ካሜራ ወይም ሰነዶች ለመምረጥ ይጫኑ')
                                : (l.isEn ? 'File attached. Tap to change.' : 'ፋይሉ ተያይዟል። ለመቀየር ይጫኑ።'),
                            style: context.sans(11, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: p.muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  _submitting
                      ? (l.isEn ? 'Submitting Receipt...' : 'ደረሰኙ እየተላከ ነው...')
                      : (l.isEn ? 'Submit Receipt for Verification' : 'ደረሰኙን ለማረጋገጫ ላክ'),
                  style: context.sans(14, weight: FontWeight.w700, color: Colors.white),
                ),
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
