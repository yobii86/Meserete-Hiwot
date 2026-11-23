import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/error_text.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../models/library.dart';
import '../../repositories/providers.dart';
import '../../widgets/dialogs.dart';
import '../admin/admin_widgets.dart' show ImageUploadTile;
import '../admin/library_admin.dart' show libraryCategoriesProvider;

/// Dedicated Physical Book Editor for Library Circulation.
class PhysicalBookEditorSheet extends ConsumerStatefulWidget {
  const PhysicalBookEditorSheet({super.key, this.book});

  final Book? book;

  @override
  ConsumerState<PhysicalBookEditorSheet> createState() => _PhysicalBookEditorSheetState();
}

class _PhysicalBookEditorSheetState extends ConsumerState<PhysicalBookEditorSheet> {
  final _form = GlobalKey<FormState>();
  late Book? _book = widget.book;

  late final _title = TextEditingController(text: _book?.title);
  late final _subtitle = TextEditingController(text: _book?.subtitle);
  late final _author = TextEditingController(text: _book?.author);
  late final _publisher = TextEditingController(text: _book?.publisher);
  late final _publicationYear = TextEditingController(text: _book?.publicationYear?.toString());
  late final String _language = _book?.language ?? 'am';
  late int? _categoryId = _book?.categoryId;
  late final _code = TextEditingController(text: _book?.code);
  late final _desc = TextEditingController(text: _book?.description);
  late final _qty = TextEditingController(text: '${_book?.quantity ?? _book?.copiesTotal ?? 1}');
  late final _condition = TextEditingController(text: _book?.condition);
  late final _location = TextEditingController(text: _book?.location);
  late final _notes = TextEditingController(text: _book?.notes);
  late String _status = _book?.status ?? 'active';
  late final String _domain = _book?.domain ?? 'mezmur';

  Object? _error;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _author.dispose();
    _publisher.dispose();
    _publicationYear.dispose();
    _code.dispose();
    _desc.dispose();
    _qty.dispose();
    _condition.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

    final body = <String, dynamic>{
      'name': _title.text.trim(),
      'subtitle': opt(_subtitle),
      'author': opt(_author),
      'publisher': opt(_publisher),
      'publication_year': int.tryParse(_publicationYear.text.trim()),
      'language': _language,
      'library_category_id': _categoryId,
      'domain': _domain,
      'kind': 'physical',
      'quantity': int.tryParse(_qty.text.trim()) ?? 1,
      'condition': opt(_condition),
      'location': opt(_location),
      'notes': opt(_notes),
      'status': _status,
      'description': opt(_desc),
      if (_code.text.trim().isNotEmpty) 'code': _code.text.trim(),
    };

    final repo = ref.read(libraryRepositoryProvider);
    try {
      final updated = _book == null
          ? await repo.createPhysicalBook(body)
          : await repo.updatePhysicalBook(_book!.id, body);

      setState(() {
        _book = updated;
        _saving = false;
      });
      ref.invalidate(libraryCategoriesProvider);
      if (mounted) {
        showSnack(context, context.l10n.saved);
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _error = e;
        _saving = false;
      });
      _form.currentState?.validate();
    }
  }

  Future<void> _uploadCover(String path) async {
    if (_book == null) {
      await showInfo(context, context.l10n.libSaveFirst);
      return;
    }
    final updated = await runWithProgress(
      context,
      () => ref.read(libraryRepositoryProvider).uploadPhysicalBookCover(_book!.id, path),
      success: context.l10n.saved,
    );
    if (updated != null && mounted) {
      setState(() => _book = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final v = Validators(l);
    final p = context.palette;

    final catsAsync = ref.watch(libraryCategoriesProvider);
    final allCats = catsAsync.value ?? const <LibraryCategory>[];
    final physicalCats = allCats.where((c) => c.categoryType == 'physical' || c.categoryType == 'both').toList();

    return SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          shrinkWrap: true,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _book == null
                            ? (isEn ? 'New Physical Book' : 'አዲስ የታተመ መጽሐፍ')
                            : (isEn ? 'Edit Physical Book' : 'የታተመ መጽሐፍ አስተካክል'),
                        style: context.serif(19, weight: FontWeight.w700),
                      ),
                      Text(
                        isEn ? 'Library Circulation & Inventory' : 'የቤተ-መጻሕፍት ስርጭትና ክምችት',
                        style: context.sans(12, color: p.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20),

            // Book Title
            TextFormField(
              controller: _title,
              validator: (s) => v.text(s, min: 2, max: 200),
              decoration: InputDecoration(
                labelText: isEn ? 'Book Title *' : 'የመጽሐፍ ርዕስ *',
                errorText: serverFieldError(l, _error, 'name'),
              ),
            ),
            const SizedBox(height: 12),

            // Subtitle
            TextFormField(
              controller: _subtitle,
              validator: (s) => v.text(s, max: 200, optional: true),
              decoration: InputDecoration(labelText: isEn ? 'Subtitle' : 'ንዑስ ርዕስ'),
            ),
            const SizedBox(height: 12),

            // Author(s)
            TextFormField(
              controller: _author,
              validator: (s) => v.text(s, max: 200, optional: true),
              decoration: InputDecoration(labelText: isEn ? 'Author(s)' : 'ደራሲ / አዘጋጅ'),
            ),
            const SizedBox(height: 12),

            // Publisher & Publication Year
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _publisher,
                    validator: (s) => v.text(s, max: 200, optional: true),
                    decoration: InputDecoration(labelText: isEn ? 'Publisher' : 'አሳታሚ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _publicationYear,
                    keyboardType: TextInputType.number,
                    validator: (s) => (s == null || s.trim().isEmpty) ? null : v.intRange(s, min: 1000, max: 2100),
                    decoration: InputDecoration(labelText: isEn ? 'Year' : 'የህትመት ዓመት', hintText: '2024'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Physical Book Category
            DropdownButtonFormField<int?>(
              key: const ValueKey('physical-category-dropdown'),
              initialValue: _categoryId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: isEn ? 'Physical Book Category' : 'የታተመ መጽሐፍ ምድብ',
              ),
              items: [
                DropdownMenuItem<int?>(value: null, child: Text(l.none)),
                for (final c in physicalCats)
                  DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text(
                      Localizations.localeOf(context).languageCode == 'en' && c.nameEn != null ? c.nameEn! : c.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (x) => setState(() => _categoryId = x),
            ),
            const SizedBox(height: 12),

            // Total Copies / Quantity & Book Code
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    validator: (s) => v.intRange(s, min: 1, max: 10000),
                    decoration: InputDecoration(
                      labelText: isEn ? 'Total Copies / Qty *' : 'አጠቃላይ ቅጂዎች / ብዛት *',
                      helperText: isEn ? 'Number of physical copies' : 'ያሉ ቅጂዎች ብዛት',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _code,
                    validator: (s) => RegExp(r'^[A-Za-z0-9_./-]{0,60}$').hasMatch(s?.trim() ?? '') ? null : l.vInvalidValue,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Item Code (Auto)' : 'የመጽሐፍ መለያ ኮድ',
                      hintText: 'LIB-CAT-001',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Physical Condition & Location
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _condition,
                    decoration: InputDecoration(labelText: isEn ? 'Condition' : 'ሁኔታ', hintText: 'አዲስ / ጥሩ / ያረጀ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _location,
                    decoration: InputDecoration(labelText: isEn ? 'Location / Shelf' : 'መደርደሪያ / ክፍል', hintText: 'መደርደሪያ 3'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: _desc,
              maxLines: 2,
              decoration: InputDecoration(labelText: isEn ? 'Description' : 'መግለጫ'),
            ),
            const SizedBox(height: 12),

            // Status Selector
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(isEn ? 'Available for Borrowing & Display' : 'ለውሰትና ለዕይታ ዝግጁ ነው'),
              subtitle: Text(
                _status == 'active' ? (isEn ? 'Active in circulation' : 'በውሰት ላይ ይገኛል') : (isEn ? 'Inactive / Retired' : 'ቦዝኗል'),
                style: context.sans(12, color: _status == 'active' ? AppColors.success : AppColors.danger),
              ),
              value: _status == 'active',
              onChanged: (on) => setState(() => _status = on ? 'active' : 'inactive'),
            ),
            const SizedBox(height: 12),

            // Cover Image Upload Tile
            ImageUploadTile(
              label: isEn ? 'Book Cover Image' : 'የመጽሐፍ ሽፋን ምስል',
              url: _book?.coverUrl,
              enabled: _book != null,
              onUpload: _uploadCover,
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger)),
              ),

            const SizedBox(height: 20),

            // Actions: Delete & Save
            Row(
              children: [
                if (_book != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    tooltip: l.delete,
                    onPressed: () async {
                      if (!await showConfirm(context, l.deleteConfirm, destructive: true) || !context.mounted) return;
                      final ok = await runWithProgress(context, () async {
                        await ref.read(libraryRepositoryProvider).deleteBook(_book!.id);
                        return true;
                      }, success: l.deleted);
                      if (ok == true && context.mounted) Navigator.pop(context, true);
                    },
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded),
                  label: Text(l.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
