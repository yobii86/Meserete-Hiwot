import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../models/library.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/dialogs.dart';
import '../../admin/admin_widgets.dart' show ImageUploadTile;
import '../../admin/library_admin.dart' show libraryCategoriesProvider, openLibraryCategoriesConfig;

/// Dedicated Digital Book Editor for Education Catalog.
/// Completely separated from generic inventory items.
class DigitalBookEditorSheet extends ConsumerStatefulWidget {
  const DigitalBookEditorSheet({super.key, this.book});

  final Book? book;

  @override
  ConsumerState<DigitalBookEditorSheet> createState() => _DigitalBookEditorSheetState();
}

class _DigitalBookEditorSheetState extends ConsumerState<DigitalBookEditorSheet> {
  final _form = GlobalKey<FormState>();
  late Book? _book = widget.book;

  late final _title = TextEditingController(text: _book?.title);
  late final _subtitle = TextEditingController(text: _book?.subtitle);
  late final _author = TextEditingController(text: _book?.author);
  late final _publisher = TextEditingController(text: _book?.publisher);
  late final _publicationYear = TextEditingController(text: _book?.publicationYear?.toString());
  late String _language = _book?.language ?? 'am';
  late int? _categoryId = _book?.categoryId;
  late final _code = TextEditingController(text: _book?.code);
  late final _desc = TextEditingController(text: _book?.description);
  late String _status = _book?.status ?? 'active';

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
      'domain': 'timhirt',
      'kind': 'digital',
      'status': _status,
      'description': opt(_desc),
      if (_code.text.trim().isNotEmpty) 'code': _code.text.trim(),
    };

    final repo = ref.read(libraryRepositoryProvider);
    try {
      final updated = _book == null
          ? await repo.createDigitalBook(body)
          : await repo.updateDigitalBook(_book!.id, body);

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

  Future<void> _uploadPdf() async {
    if (_book == null) {
      await showInfo(context, context.l10n.libSaveFirst);
      return;
    }
    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf']);
    final path = res.isNotEmpty ? res.first.path : null;
    if (path == null || !mounted) return;

    final updated = await runWithProgress(
      context,
      () => ref.read(libraryRepositoryProvider).uploadDigitalBookPdf(_book!.id, path),
      success: context.l10n.libPdfUploaded,
    );
    if (updated != null && mounted) {
      setState(() => _book = updated);
    }
  }

  Future<void> _uploadCover(String path) async {
    if (_book == null) {
      await showInfo(context, context.l10n.libSaveFirst);
      return;
    }
    final updated = await runWithProgress(
      context,
      () => ref.read(libraryRepositoryProvider).uploadDigitalBookCover(_book!.id, path),
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
    // Education digital book categories only
    final digitalCats = allCats.where((c) => c.categoryType == 'digital' || c.categoryType == 'both').toList();

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
                            ? (isEn ? 'New Digital Book' : 'አዲስ ዲጂታል መጽሐፍ')
                            : (isEn ? 'Edit Digital Book' : 'ዲጂታል መጽሐፍ አስተካክል'),
                        style: context.serif(19, weight: FontWeight.w700),
                      ),
                      Text(
                        isEn ? 'Education Library Catalog' : 'የትምህርት መጻሕፍት ካታሎግ',
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
              decoration: InputDecoration(
                labelText: isEn ? 'Subtitle' : 'ንዑስ ርዕስ',
                errorText: serverFieldError(l, _error, 'subtitle'),
              ),
            ),
            const SizedBox(height: 12),

            // Author(s)
            TextFormField(
              controller: _author,
              validator: (s) => v.text(s, max: 200, optional: true),
              decoration: InputDecoration(
                labelText: isEn ? 'Author(s)' : 'ደራሲ / አዘጋጅ',
                errorText: serverFieldError(l, _error, 'author'),
              ),
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
                    decoration: InputDecoration(
                      labelText: isEn ? 'Year' : 'የህትመት ዓመት',
                      hintText: '2024',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Language & Digital Category
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _language,
                    decoration: InputDecoration(labelText: isEn ? 'Language' : 'ቋንቋ'),
                    items: const [
                      DropdownMenuItem(value: 'am', child: Text('አማርኛ')),
                      DropdownMenuItem(value: 'gez', child: Text('ግዕዝ')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'om', child: Text('Afaan Oromoo')),
                      DropdownMenuItem(value: 'ti', child: Text('ትግርኛ')),
                    ],
                    onChanged: (x) => setState(() => _language = x ?? 'am'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: catsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                    ),
                    error: (e, _) => Text(
                      isEn ? 'Failed to load categories' : 'ምድቦችን መጫን አልተቻለም',
                      style: context.sans(12, color: AppColors.danger),
                    ),
                    data: (_) {
                      final effectiveCats = digitalCats;
                      if (effectiveCats.isEmpty) {
                        return OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            side: BorderSide(color: AppColors.maroon.withValues(alpha: 0.4)),
                          ),
                          icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.maroon),
                          label: Text(
                            isEn ? '+ Create Digital Category' : '+ የዲጂታል ምድብ ፍጠር',
                            style: context.sans(12, weight: FontWeight.w700, color: AppColors.maroon),
                          ),
                          onPressed: () async {
                            await openLibraryCategoriesConfig(context, ref);
                            ref.invalidate(libraryCategoriesProvider);
                          },
                        );
                      }

                      // If valid categories exist, ensure a valid selection
                      final selectedValue = (_categoryId != null && effectiveCats.any((c) => c.id == _categoryId))
                          ? _categoryId
                          : effectiveCats.first.id;

                      if (_categoryId != selectedValue) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _categoryId = selectedValue);
                        });
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              key: ValueKey('digital-cat-dropdown-${effectiveCats.length}-$selectedValue'),
                              initialValue: selectedValue,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: isEn ? 'Book Category *' : 'የመጽሐፍ ምድብ *',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              items: [
                                for (final c in effectiveCats)
                                  DropdownMenuItem<int?>(
                                    value: c.id,
                                    child: Text(
                                      Localizations.localeOf(context).languageCode == 'en' && c.nameEn != null ? c.nameEn! : c.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.sans(13),
                                    ),
                                  ),
                              ],
                              onChanged: (x) => setState(() => _categoryId = x),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: isEn ? 'Manage Categories' : 'ምድቦችን አስተዳድር',
                            icon: const Icon(Icons.tune_rounded, size: 20),
                            onPressed: () async {
                              await openLibraryCategoriesConfig(context, ref);
                              ref.invalidate(libraryCategoriesProvider);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Book Code (optional, auto-generated if blank)
            TextFormField(
              controller: _code,
              validator: (s) => RegExp(r'^[A-Za-z0-9_./-]{0,60}$').hasMatch(s?.trim() ?? '') ? null : l.vInvalidValue,
              decoration: InputDecoration(
                labelText: isEn ? 'Book Code (leave blank to auto-generate)' : 'የመጽሐፍ ኮድ (ባዶ ከተተወ በራሱ ይወጣል)',
                hintText: 'DIG-EDU-001',
                errorText: serverFieldError(l, _error, 'code'),
              ),
            ),
            const SizedBox(height: 12),

            // Description / Summary
            TextFormField(
              controller: _desc,
              maxLines: 3,
              validator: (s) => v.text(s, max: 2000, optional: true),
              decoration: InputDecoration(
                labelText: isEn ? 'Description / Summary' : 'አጭር መግለጫ / ማጠቃለያ',
              ),
            ),
            const SizedBox(height: 12),

            // Status Selector (Active / Inactive)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(isEn ? 'Active in Education Catalog' : 'በትምህርት ካታሎግ ላይ ይታይ (ገባሪ)'),
              subtitle: Text(
                _status == 'active'
                    ? (isEn ? 'Visible to enrolled students and authorized members' : 'ለተማሪዎችና ለአባላት ይታያል')
                    : (isEn ? 'Disabled / Hidden from catalog' : 'ከካታሎጉ ተደብቋል (ቦዝኗል)'),
                style: context.sans(12, color: _status == 'active' ? AppColors.success : AppColors.danger),
              ),
              value: _status == 'active',
              onChanged: (on) => setState(() => _status = on ? 'active' : 'inactive'),
            ),
            const Divider(height: 24),

            // PDF Document Tile
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.picture_as_pdf_rounded,
                color: (_book?.hasFile ?? false) ? AppColors.success : AppColors.danger,
                size: 32,
              ),
              title: Text(
                (_book?.hasFile ?? false)
                    ? (isEn ? 'PDF Document Uploaded' : 'የመጽሐፉ ፒዲኤፍ (PDF) ተጭኗል')
                    : (isEn ? 'Upload PDF Document' : 'የመጽሐፉን ፒዲኤፍ (PDF) ጫን'),
                style: context.sans(14, weight: FontWeight.w600),
              ),
              subtitle: _book == null
                  ? Text(isEn ? 'Save metadata first before uploading PDF' : 'መጀመሪያ መረጃውን ያስቀምጡ')
                  : Text(
                      (_book?.downloads ?? 0) > 0
                          ? l.libDownloads('${_book!.downloads}')
                          : (isEn ? 'Tap to replace or upload new PDF' : 'አዲስ ፒዲኤፍ ለመቀየር ይጫኑ'),
                      style: context.sans(12, color: p.muted),
                    ),
              trailing: const Icon(Icons.upload_file_rounded),
              enabled: _book != null,
              onTap: _uploadPdf,
            ),
            const SizedBox(height: 12),

            // Cover Image Upload Tile
            ImageUploadTile(
              label: isEn ? 'Book Cover Image' : 'የመጽሐፍ ሽፋን ምስል',
              url: _book?.coverUrl,
              enabled: _book != null,
              onUpload: _uploadCover,
            ),

            if (_error != null && (serverFieldError(l, _error, 'code') == null && serverFieldError(l, _error, 'name') == null))
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
