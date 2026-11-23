import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/library.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show AdminScaffold, SearchBox, captureSignature, pickUsers;

String copyConditionLabel(AppLocalizations l, String cond) => switch (cond) {
      'fair' => l.libFair,
      'poor' => l.libPoor,
      'damaged' => l.libDamaged,
      _ => l.libGood,
    };

Color copyConditionColor(String cond) => switch (cond) {
      'good' => AppColors.success,
      'fair' => AppColors.goldDark,
      'poor' => Colors.deepOrange,
      'damaged' => AppColors.danger,
      _ => AppColors.faint,
    };

String copyStatusLabel(AppLocalizations l, String status) => switch (status) {
      'on_loan' => l.libStatusOnLoan,
      'lost' => l.libStatusLost,
      'withdrawn' => l.libStatusWithdrawn,
      _ => l.libStatusAvailable,
    };

Color copyStatusColor(String status) => switch (status) {
      'available' => AppColors.success,
      'on_loan' => const Color(0xFF1F5F8B),
      'lost' => Colors.deepOrange,
      'withdrawn' => AppColors.danger,
      _ => AppColors.faint,
    };

/// Sunday-School physical library circulation screen (F17).
/// Manages checkout with borrower signatures, active loans, returns, and overdue tracking.
class LibraryCirculationScreen extends StatefulWidget {
  const LibraryCirculationScreen({super.key, this.initialCopyCode});
  final String? initialCopyCode;

  @override
  State<LibraryCirculationScreen> createState() => _LibraryCirculationScreenState();
}

class _LibraryCirculationScreenState extends State<LibraryCirculationScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AdminScaffold(
      title: l.libCirculation,
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabs: [
          Tab(icon: const Icon(Icons.outbox_rounded), text: l.libCheckout),
          Tab(icon: const Icon(Icons.menu_book_rounded), text: l.libActiveLoans),
          Tab(icon: const Icon(Icons.inventory_2_outlined), text: l.libCopies),
          Tab(icon: const Icon(Icons.alarm_on_rounded), text: l.libOverdue),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _CheckoutTab(
            initialCode: widget.initialCopyCode,
            onCheckedOut: () => _tabs.animateTo(1),
          ),
          const _LoansTab(),
          const _CopiesTab(),
          const _OverdueTab(),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab 1: Check Out (Scan/enter copy, borrower lookup, signature, checkout)
// =============================================================================
class _CheckoutTab extends ConsumerStatefulWidget {
  const _CheckoutTab({this.initialCode, required this.onCheckedOut});
  final String? initialCode;
  final VoidCallback onCheckedOut;

  @override
  ConsumerState<_CheckoutTab> createState() => _CheckoutTabState();
}

class _CheckoutTabState extends ConsumerState<_CheckoutTab> {
  final _codeCtrl = TextEditingController();
  final _daysCtrl = TextEditingController(text: '14');
  final _notesCtrl = TextEditingController();

  LibraryCopy? _copy;
  bool _lookingUpCopy = false;
  String? _copyError;

  int? _borrowerId;
  String? _borrowerName;
  String? _borrowerMemberId;
  String? _borrowerPhone;

  String _conditionOut = 'good';
  String? _signature;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _codeCtrl.text = widget.initialCode!;
      _lookupCopy(widget.initialCode!);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _daysCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupCopy(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _lookingUpCopy = true;
      _copyError = null;
    });
    try {
      final copy = await ref.read(libraryRepositoryProvider).findCopyByCode(trimmed);
      if (!mounted) return;
      setState(() {
        _copy = copy;
        _conditionOut = copy.condition;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _copy = null;
        _copyError = context.l10n.libCopyNotFound;
      });
    } finally {
      if (mounted) setState(() => _lookingUpCopy = false);
    }
  }

  Future<void> _scanBarcode() async {
    final scanned = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.libScanQr)),
        body: MobileScanner(
          onDetect: (capture) {
            final barcode = capture.barcodes.firstOrNull?.rawValue;
            if (barcode != null && barcode.isNotEmpty) {
              Navigator.pop(ctx, barcode);
            }
          },
        ),
      ),
    );
    if (scanned != null && mounted) {
      _codeCtrl.text = scanned;
      await _lookupCopy(scanned);
    }
  }

  Future<void> _openBookPicker() async {
    final copyCode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PhysicalBookPickerDialog(),
    );
    if (copyCode != null && mounted) {
      _codeCtrl.text = copyCode;
      await _lookupCopy(copyCode);
    }
  }

  Future<void> _selectBorrower() async {
    final sel = await pickUsers(context, multiple: false);
    if (sel != null && sel.ids.isNotEmpty && mounted) {
      final id = sel.ids.first;
      setState(() {
        _borrowerId = id;
        _borrowerName = sel.names[id] ?? 'User #$id';
        _borrowerMemberId = null;
        _borrowerPhone = null;
      });
    }
  }

  Future<void> _sign() async {
    if (_borrowerName == null) {
      showSnack(context, context.l10n.libSelectBorrower);
      return;
    }
    final sig = await captureSignature(context, name: _borrowerName!);
    if (sig != null && sig.isNotEmpty && mounted) {
      setState(() => _signature = sig);
    }
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final copy = _copy;
    if (copy == null) {
      showSnack(context, l.libEnterCopyCode);
      return;
    }
    if (!copy.isAvailable) {
      showSnack(context, l.libConflictOnLoan);
      return;
    }
    if (_borrowerId == null) {
      showSnack(context, l.libSelectBorrower);
      return;
    }
    if (_signature == null || _signature!.isEmpty) {
      showSnack(context, l.libSignatureRequired);
      return;
    }

    final loanDays = int.tryParse(_daysCtrl.text.trim()) ?? 14;
    final outcome = await runWithProgress(
      context,
      () => ref.read(libraryRepositoryProvider).checkout(
            copyId: copy.id,
            userId: _borrowerId!,
            signature: _signature!,
            loanDays: loanDays,
            conditionOut: _conditionOut,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          ),
      success: l.libCheckoutSuccess,
    );

    if (outcome != null && mounted) {
      if (outcome.conflict) {
        showSnack(context, l.libConflictOnLoan);
      } else {
        setState(() {
          _copy = null;
          _borrowerId = null;
          _borrowerName = null;
          _signature = null;
          _codeCtrl.clear();
          _notesCtrl.clear();
        });
        widget.onCheckedOut();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final copy = _copy;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // 1. Copy lookup card
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('checkout-copy-code-input'),
                  controller: _codeCtrl,
                  decoration: InputDecoration(
                    labelText: l.libCopyCode,
                    hintText: 'e.g. LIB-TM-0001-01',
                    isDense: true,
                    prefixIcon: const Icon(Icons.qr_code_2_rounded, color: AppColors.gold),
                  ),
                  onSubmitted: _lookupCopy,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: l.libScanQr,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                onPressed: _scanBarcode,
              ),
              const SizedBox(width: 4),
              FilledButton(
                key: const ValueKey('checkout-copy-search-btn'),
                onPressed: () => _lookupCopy(_codeCtrl.text),
                child: Text(l.search),
              ),
            ]),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('checkout-pick-book-btn'),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text(l.isEn ? 'Browse & Select Available Book' : 'የሚገኙ መጻሕፍትን ፈልገው ይምረጡ'),
              onPressed: _openBookPicker,
            ),
            if (_lookingUpCopy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_copyError != null) ...[
              const SizedBox(height: 8),
              Text(_copyError!, style: context.sans(13, color: AppColors.danger)),
            ],
            if (copy != null) ...[
              const Divider(height: 24),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.menu_book_rounded, color: AppColors.gold, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(copy.bookTitle ?? 'Book #${copy.itemId}', style: context.serif(15, weight: FontWeight.w600)),
                    if (copy.bookAuthor != null) Text(copy.bookAuthor!, style: context.sans(12, color: p.muted)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      Pill(copy.copyCode, color: AppColors.goldDark),
                      Pill(copyConditionLabel(l, copy.condition), color: copyConditionColor(copy.condition)),
                      Pill(copyStatusLabel(l, copy.status), color: copyStatusColor(copy.status)),
                      if (copy.location != null) Pill(copy.location!, color: p.muted),
                    ]),
                    if (copy.isOnLoan && copy.currentLoan != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          '${l.libConflictOnLoan}: ${copy.currentLoan!.borrowerName ?? ''}',
                          style: context.sans(12, color: AppColors.danger, weight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ]),
                ),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // 2. Borrower Card
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(l.libBorrower, style: context.serif(15, weight: FontWeight.w600)),
              FilledButton.tonalIcon(
                key: const ValueKey('checkout-select-borrower-btn'),
                onPressed: _selectBorrower,
                icon: const Icon(Icons.person_search_rounded, size: 18),
                label: Text(_borrowerId == null ? l.libSelectBorrower : l.change),
              ),
            ]),
            if (_borrowerName != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.account_circle_rounded, color: AppColors.gold, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_borrowerName!, style: context.sans(14, weight: FontWeight.w600)),
                      if (_borrowerPhone != null || _borrowerMemberId != null)
                        Text([?_borrowerMemberId, ?_borrowerPhone].join(' · '), style: context.sans(12, color: p.muted)),
                    ]),
                  ),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // 3. Loan options
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _conditionOut,
                  decoration: InputDecoration(labelText: l.libConditionOut, isDense: true),
                  items: [
                    DropdownMenuItem(value: 'good', child: Text(l.libGood)),
                    DropdownMenuItem(value: 'fair', child: Text(l.libFair)),
                    DropdownMenuItem(value: 'poor', child: Text(l.libPoor)),
                    DropdownMenuItem(value: 'damaged', child: Text(l.libDamaged)),
                  ],
                  onChanged: (v) => setState(() => _conditionOut = v ?? 'good'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _daysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.libLoanDays, isDense: true),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(labelText: l.libRequestNote, isDense: true),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // 4. Signature capture
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(l.libSignToBorrow, style: context.serif(15, weight: FontWeight.w600)),
              OutlinedButton.icon(
                key: const ValueKey('checkout-capture-sig-btn'),
                onPressed: _sign,
                icon: const Icon(Icons.draw_rounded, size: 18),
                label: Text(_signature == null ? l.libSignToBorrow : l.change),
              ),
            ]),
            if (_signature != null) ...[
              const SizedBox(height: 8),
              Container(
                height: 80,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.gold)),
                child: const Center(child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36)),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 24),

        // Submit button
        FilledButton(
          key: const ValueKey('checkout-submit-btn'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: (_copy != null && _copy!.isAvailable && _borrowerId != null && _signature != null) ? _submit : null,
          child: Text(l.libCheckout, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// =============================================================================
// Tab 2: Active Loans & Return
// =============================================================================
class _LoansTab extends ConsumerStatefulWidget {
  const _LoansTab();
  @override
  ConsumerState<_LoansTab> createState() => _LoansTabState();
}

class _LoansTabState extends ConsumerState<_LoansTab> {
  final _ctrl = PagedListController<LibraryLoan>();
  String _q = '';
  bool _groupByBook = false;

  Future<void> _returnLoan(LibraryLoan loan) async {
    final l = context.l10n;
    var conditionIn = 'good';
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l.libReturn),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${loan.bookTitle ?? 'Book'} · ${loan.copyCode}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: conditionIn,
              decoration: InputDecoration(labelText: l.libConditionIn, isDense: true),
              items: [
                DropdownMenuItem(value: 'good', child: Text(l.libGood)),
                DropdownMenuItem(value: 'fair', child: Text(l.libFair)),
                DropdownMenuItem(value: 'poor', child: Text(l.libPoor)),
                DropdownMenuItem(value: 'damaged', child: Text(l.libDamaged)),
              ],
              onChanged: (v) => setS(() => conditionIn = v ?? 'good'),
            ),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl, decoration: InputDecoration(labelText: l.libRequestNote, isDense: true)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(
              key: const ValueKey('loan-return-confirm-btn'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.libReturn),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    final outcome = await runWithProgress(
      context,
      () => ref.read(libraryRepositoryProvider).returnCopy(
            loan.id,
            conditionIn: conditionIn,
            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
          ),
      success: l.libReturnSuccess,
    );

    if (outcome != null) {
      await _ctrl.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            Expanded(child: SearchBox(onChanged: (v) => setState(() => _q = v))),
            const SizedBox(width: 8),
            FilterChip(
              avatar: Icon(_groupByBook ? Icons.view_agenda_rounded : Icons.view_headline_rounded, size: 16),
              label: Text(l.isEn ? 'Group' : 'በመጽሐፍ'),
              selected: _groupByBook,
              onSelected: (val) => setState(() => _groupByBook = val),
            ),
          ],
        ),
      ),
      if (_groupByBook)
        Expanded(
          child: _GroupedLoansView(
            key: ValueKey('grouped-$_q'),
            q: _q,
            onReturn: _returnLoan,
          ),
        )
      else
        Expanded(
          child: PagedListView<LibraryLoan>(
            key: ValueKey(_q),
            controller: _ctrl,
            fetch: (page) => ref.read(libraryRepositoryProvider).loans(status: 'active', q: _q.isEmpty ? null : _q, page: page),
          emptyMessage: l.noResults,
          emptyIcon: Icons.menu_book_outlined,
          itemBuilder: (context, loan, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Pill(loan.copyCode, color: AppColors.goldDark),
                  if (loan.isOverdue)
                    Pill(l.libOverdue, color: AppColors.danger)
                  else
                    Pill(l.libStatusOnLoan, color: const Color(0xFF1F5F8B)),
                ]),
                const SizedBox(height: 8),
                Text(loan.bookTitle ?? 'Book #${loan.bookId}', style: context.serif(15, weight: FontWeight.w600)),
                if (loan.bookAuthor != null) Text(loan.bookAuthor!, style: context.sans(12, color: p.muted)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.gold),
                  const SizedBox(width: 4),
                  Text(loan.borrowerName ?? 'Member #${loan.userId}', style: context.sans(13, weight: FontWeight.w500)),
                  if (loan.borrowerPhone != null) Text(' · ${loan.borrowerPhone}', style: context.sans(12, color: p.muted)),
                ]),
                const SizedBox(height: 4),
                Text(
                  '${l.libDueOn}: ${loan.dueOn != null ? f.date(loan.dueOn!) : '—'}',
                  style: context.sans(12, color: loan.isOverdue ? AppColors.danger : p.muted, weight: loan.isOverdue ? FontWeight.bold : FontWeight.normal),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    key: ValueKey('loan-return-btn-${loan.id}'),
                    onPressed: () => _returnLoan(loan),
                    child: Text(l.libReturn),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

// =============================================================================
// Tab 3: Copies / Inventory
// =============================================================================
class _CopiesTab extends ConsumerStatefulWidget {
  const _CopiesTab();
  @override
  ConsumerState<_CopiesTab> createState() => _CopiesTabState();
}

class _CopiesTabState extends ConsumerState<_CopiesTab> {
  final _ctrl = PagedListController<LibraryCopy>();
  String _q = '';
  String? _status;
  bool _groupByBook = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;

    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: SearchBox(onChanged: (v) => setState(() => _q = v))),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          FilterChip(
            avatar: Icon(_groupByBook ? Icons.view_agenda_rounded : Icons.view_headline_rounded, size: 16),
            label: Text(l.isEn ? 'Group' : 'በመጽሐፍ'),
            selected: _groupByBook,
            onSelected: (val) => setState(() => _groupByBook = val),
          ),
          const SizedBox(width: 8),
          FilterChip(label: Text(l.all), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
          const SizedBox(width: 6),
          FilterChip(label: Text(l.libStatusAvailable), selected: _status == 'available', onSelected: (_) => setState(() => _status = 'available')),
          const SizedBox(width: 6),
          FilterChip(label: Text(l.libStatusOnLoan), selected: _status == 'on_loan', onSelected: (_) => setState(() => _status = 'on_loan')),
          const SizedBox(width: 6),
          FilterChip(label: Text(l.libStatusLost), selected: _status == 'lost', onSelected: (_) => setState(() => _status = 'lost')),
          const SizedBox(width: 6),
          FilterChip(label: Text(l.libStatusWithdrawn), selected: _status == 'withdrawn', onSelected: (_) => setState(() => _status = 'withdrawn')),
        ]),
      ),
      if (_groupByBook)
        Expanded(
          child: _GroupedCopiesView(
            key: ValueKey('grouped-$_q-$_status'),
            q: _q,
            status: _status,
          ),
        )
      else
        Expanded(
          child: PagedListView<LibraryCopy>(
            key: ValueKey('$_q-$_status'),
            controller: _ctrl,
            fetch: (page) => ref.read(libraryRepositoryProvider).copies(q: _q.isEmpty ? null : _q, status: _status, page: page),
          emptyMessage: l.noResults,
          emptyIcon: Icons.inventory_2_outlined,
          itemBuilder: (context, c, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.bookmark_border_rounded, color: AppColors.gold, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.bookTitle ?? 'Book #${c.itemId}', style: context.serif(15, weight: FontWeight.w600)),
                    if (c.bookAuthor != null) Text(c.bookAuthor!, style: context.sans(12, color: p.muted)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      Pill(c.copyCode, color: AppColors.goldDark),
                      Pill(copyConditionLabel(l, c.condition), color: copyConditionColor(c.condition)),
                      Pill(copyStatusLabel(l, c.status), color: copyStatusColor(c.status)),
                      if (c.location != null) Pill(c.location!, color: p.muted),
                    ]),
                    if (c.isOnLoan && c.currentLoan != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${l.libStatusOnLoan}: ${c.currentLoan!.borrowerName ?? ''}',
                        style: context.sans(12, color: const Color(0xFF1F5F8B), weight: FontWeight.w500),
                      ),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

// =============================================================================
// Tab 4: Overdue Loans
// =============================================================================
class _OverdueTab extends ConsumerStatefulWidget {
  const _OverdueTab();
  @override
  ConsumerState<_OverdueTab> createState() => _OverdueTabState();
}

class _OverdueTabState extends ConsumerState<_OverdueTab> {
  final _ctrl = PagedListController<LibraryLoan>();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);

    return PagedListView<LibraryLoan>(
      controller: _ctrl,
      fetch: (page) => ref.read(libraryRepositoryProvider).overdue(page: page),
      emptyMessage: l.noResults,
      emptyIcon: Icons.alarm_on_rounded,
      itemBuilder: (context, loan, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Pill(loan.copyCode, color: AppColors.goldDark),
              Pill(l.libOverdue, color: AppColors.danger),
            ]),
            const SizedBox(height: 8),
            Text(loan.bookTitle ?? 'Book #${loan.bookId}', style: context.serif(15, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.danger),
              const SizedBox(width: 4),
              Text(loan.borrowerName ?? 'Member #${loan.userId}', style: context.sans(13, weight: FontWeight.w500)),
              if (loan.borrowerPhone != null) Text(' · ${loan.borrowerPhone}', style: context.sans(12, color: p.muted)),
            ]),
            const SizedBox(height: 4),
            Text('${l.libDueOn}: ${loan.dueOn != null ? f.date(loan.dueOn!) : '—'}', style: context.sans(12, color: AppColors.danger, weight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }
}

// =============================================================================
// Grouped Loans View
// =============================================================================
class _GroupedLoansView extends ConsumerStatefulWidget {
  const _GroupedLoansView({super.key, required this.q, required this.onReturn});
  final String q;
  final Future<void> Function(LibraryLoan) onReturn;

  @override
  ConsumerState<_GroupedLoansView> createState() => _GroupedLoansViewState();
}

class _GroupedLoansViewState extends ConsumerState<_GroupedLoansView> {
  bool _loading = true;
  List<LibraryLoan> _loans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(libraryRepositoryProvider).loans(status: 'active', q: widget.q.isEmpty ? null : widget.q);
      if (mounted) {
        setState(() {
          _loans = res.items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 48, color: p.muted.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text(l.noResults, style: TextStyle(color: p.muted)),
          ],
        ),
      );
    }

    final Map<int, List<LibraryLoan>> groups = {};
    for (final loan in _loans) {
      groups.putIfAbsent(loan.bookId, () => []).add(loan);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: groups.keys.length,
        itemBuilder: (ctx, i) {
          final bookId = groups.keys.elementAt(i);
          final bookLoans = groups[bookId]!;
          final first = bookLoans.first;
          final title = first.bookTitle ?? 'Book #$bookId';
          final author = first.bookAuthor;

          return AppCard(
            padding: const EdgeInsets.all(12),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              leading: const Icon(Icons.menu_book_rounded, color: AppColors.gold, size: 28),
              title: Text(title, style: context.serif(15, weight: FontWeight.w700)),
              subtitle: Row(
                children: [
                  if (author != null) ...[
                    Flexible(child: Text(author, style: context.sans(12, color: p.muted), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                  ],
                  Pill(
                    '${bookLoans.length} ${l.isEn ? 'active' : 'ተወስደዋል'}',
                    color: const Color(0xFF1F5F8B),
                  ),
                ],
              ),
              children: bookLoans.map((loan) {
                return Container(
                          padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.fill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Pill(loan.copyCode, color: AppColors.goldDark),
                                const SizedBox(width: 6),
                                if (loan.isOverdue)
                                  Pill(l.libOverdue, color: AppColors.danger)
                                else
                                  Pill(l.libStatusOnLoan, color: const Color(0xFF1F5F8B)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${loan.borrowerName ?? 'Member #${loan.userId}'}${loan.borrowerPhone != null ? ' · ${loan.borrowerPhone}' : ''}',
                              style: context.sans(13, weight: FontWeight.w600),
                            ),
                            Text(
                              '${l.libDueOn}: ${loan.dueOn != null ? f.date(loan.dueOn!) : '—'}',
                              style: context.sans(11.5, color: loan.isOverdue ? AppColors.danger : p.subtle),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        key: ValueKey('grouped-return-btn-${loan.id}'),
                        onPressed: () async {
                          await widget.onReturn(loan);
                          _load();
                        },
                        child: Text(l.libReturn),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Grouped Copies View
// =============================================================================
class _GroupedCopiesView extends ConsumerStatefulWidget {
  const _GroupedCopiesView({super.key, required this.q, this.status});
  final String q;
  final String? status;

  @override
  ConsumerState<_GroupedCopiesView> createState() => _GroupedCopiesViewState();
}

class _GroupedCopiesViewState extends ConsumerState<_GroupedCopiesView> {
  bool _loading = true;
  List<LibraryCopy> _copies = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(libraryRepositoryProvider).copies(q: widget.q.isEmpty ? null : widget.q, status: widget.status);
      if (mounted) {
        setState(() {
          _copies = res.items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_copies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: p.muted.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text(l.noResults, style: TextStyle(color: p.muted)),
          ],
        ),
      );
    }

    final Map<int, List<LibraryCopy>> groups = {};
    for (final copy in _copies) {
      groups.putIfAbsent(copy.itemId, () => []).add(copy);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: groups.keys.length,
        itemBuilder: (ctx, i) {
          final itemId = groups.keys.elementAt(i);
          final bookCopies = groups[itemId]!;
          final first = bookCopies.first;
          final title = first.bookTitle ?? 'Book #$itemId';
          final author = first.bookAuthor;
          final availableCount = bookCopies.where((c) => c.isAvailable).length;

          return AppCard(
            padding: const EdgeInsets.all(12),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              leading: const Icon(Icons.bookmark_border_rounded, color: AppColors.gold, size: 28),
              title: Text(title, style: context.serif(15, weight: FontWeight.w700)),
              subtitle: Row(
                children: [
                  if (author != null) ...[
                    Flexible(child: Text(author, style: context.sans(12, color: p.muted), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                  ],
                  Pill(
                    '$availableCount/${bookCopies.length} ${l.isEn ? 'Available' : 'ይገኛሉ'}',
                    color: availableCount > 0 ? AppColors.success : Colors.grey,
                  ),
                ],
              ),
              children: bookCopies.map((c) {
                return Container(
                          padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.fill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              Pill(c.copyCode, color: AppColors.goldDark),
                              Pill(copyConditionLabel(l, c.condition), color: copyConditionColor(c.condition)),
                              Pill(copyStatusLabel(l, c.status), color: copyStatusColor(c.status)),
                              if (c.location != null) Pill(c.location!, color: p.muted),
                            ]),
                            if (c.isOnLoan && c.currentLoan != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${l.libStatusOnLoan}: ${c.currentLoan!.borrowerName ?? ''}',
                                style: context.sans(12, color: const Color(0xFF1F5F8B), weight: FontWeight.w500),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Searchable Available Physical Books Picker Dialog
// =============================================================================
class _PhysicalBookPickerDialog extends ConsumerStatefulWidget {
  const _PhysicalBookPickerDialog();

  @override
  ConsumerState<_PhysicalBookPickerDialog> createState() => _PhysicalBookPickerDialogState();
}

class _PhysicalBookPickerDialogState extends ConsumerState<_PhysicalBookPickerDialog> {
  final _searchCtrl = TextEditingController();
  int? _selectedCatId;
  bool _loading = false;
  List<Book> _books = [];
  List<LibraryCategory> _categories = [];
  Book? _selectedBook;
  List<LibraryCopy> _bookCopies = [];
  bool _loadingCopies = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(libraryRepositoryProvider);
      final cats = await repo.categories(type: 'physical');
      final page = await repo.books(kind: 'physical');
      if (mounted) {
        setState(() {
          _categories = cats;
          _books = page.items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(libraryRepositoryProvider);
      final page = await repo.books(
        kind: 'physical',
        categoryId: _selectedCatId,
        q: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _books = page.items;
          _loading = false;
          _selectedBook = null;
          _bookCopies = [];
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectBook(Book b) async {
    setState(() {
      _selectedBook = b;
      _loadingCopies = true;
      _bookCopies = [];
    });
    try {
      final repo = ref.read(libraryRepositoryProvider);
      final page = await repo.copies(itemId: b.id, status: 'available');
      if (mounted) {
        setState(() {
          _bookCopies = page.items;
          _loadingCopies = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCopies = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded, color: AppColors.goldDark, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEn ? 'Select Physical Book' : 'የሚገኙ መጻሕፍትን ይምረጡ',
                    style: context.serif(17, weight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: isEn ? 'Search by title or author...' : 'በርዕስ ወይም በደራሲ ፈልግ...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _search();
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: p.fill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(l.all),
                    selected: _selectedCatId == null,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedCatId = null);
                        _search();
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  ..._categories.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(isEn ? (c.nameEn ?? c.name) : c.name),
                          selected: _selectedCatId == c.id,
                          onSelected: (val) {
                            setState(() => _selectedCatId = val ? c.id : null);
                            _search();
                          },
                        ),
                      )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: _selectedBook != null
                ? _buildCopiesSelectionView(isEn, p, l)
                : _buildBooksListView(isEn, p, l),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksListView(bool isEn, Palette p, AppLocalizations l) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_books.isEmpty) {
      return Center(
        child: Text(
          isEn ? 'No physical books found' : 'ምንም መጽሐፍ አልተገኘም',
          style: TextStyle(color: p.muted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _books.length,
      itemBuilder: (ctx, i) {
        final b = _books[i];
        final avail = b.effectiveAvailable;
        final total = b.effectiveTotal;
        final isAvailable = avail > 0;

        return AppCard(
          padding: const EdgeInsets.all(12),
          onTap: isAvailable ? () => _selectBook(b) : null,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 56,
                decoration: BoxDecoration(
                  color: isAvailable ? const Color(0xFF650D20).withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: isAvailable ? const Color(0xFF650D20) : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.title, style: context.serif(14.5, weight: FontWeight.w700)),
                    if (b.author != null)
                      Text(b.author!, style: context.sans(12, color: AppColors.goldDark, weight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (b.categoryName != null) ...[
                          Text(b.categoryName!, style: context.sans(11, color: p.muted)),
                          const SizedBox(width: 8),
                        ],
                        Pill(
                          isAvailable
                              ? (isEn ? '$avail of $total Available' : '$avail ከ $total ይገኛሉ')
                              : (isEn ? 'None Available' : 'አልተገኘም'),
                          color: isAvailable ? AppColors.success : Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isAvailable) const Icon(Icons.chevron_right_rounded, color: AppColors.goldDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCopiesSelectionView(bool isEn, Palette p, AppLocalizations l) {
    final b = _selectedBook!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: p.fill,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _selectedBook = null),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.title, style: context.serif(14.5, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(isEn ? 'Select an available copy below:' : 'ከዚህ በታች የሚገኝ ቅጅ ይምረጡ፡', style: context.sans(11.5, color: p.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingCopies
              ? const Center(child: CircularProgressIndicator())
              : _bookCopies.isEmpty
                  ? Center(
                      child: Text(
                        isEn ? 'No available copies for this book' : 'ለዚህ መጽሐፍ የሚገኝ ቅጅ የለም',
                        style: TextStyle(color: p.muted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _bookCopies.length,
                      itemBuilder: (ctx, i) {
                        final copy = _bookCopies[i];
                        return AppCard(
                                          padding: const EdgeInsets.all(12),
                          onTap: () => Navigator.pop(context, copy.copyCode),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Pill(copy.copyCode, color: AppColors.goldDark),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Pill(copyConditionLabel(l, copy.condition), color: copyConditionColor(copy.condition)),
                                      if (copy.location != null) ...[
                                        const SizedBox(width: 6),
                                        Pill(copy.location!, color: p.muted),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              FilledButton.tonal(
                                onPressed: () => Navigator.pop(context, copy.copyCode),
                                child: Text(isEn ? 'Select' : 'ምረጥ'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

