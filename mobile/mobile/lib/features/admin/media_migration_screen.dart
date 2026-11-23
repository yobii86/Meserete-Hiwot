import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Admin Media Migration & Optimization Dashboard
/// Manages conversions for:
/// - Audio -> MP3 (128 kbps / compact mobile streaming)
/// - Images -> WebP (alpha transparency, compact size)
/// - PDF Documents -> Pre-rendered WebP Pages for instant in-app viewing
class MediaMigrationAdminScreen extends ConsumerStatefulWidget {
  const MediaMigrationAdminScreen({super.key});

  @override
  ConsumerState<MediaMigrationAdminScreen> createState() => _MediaMigrationAdminScreenState();
}

class _MediaMigrationAdminScreenState extends ConsumerState<MediaMigrationAdminScreen> {
  bool _isLoading = true;
  bool _isOperating = false;
  bool _dryRun = false;
  bool _forceRescan = false;
  String _selectedType = 'all'; // 'all', 'audio', 'image', 'pdf'
  String _statusFilter = 'all'; // 'all', 'pending', 'completed', 'failed', 'skipped'
  String _audioFormat = 'm4a'; // 'm4a' (AAC) or 'mp3'
  int _audioBitrate = 128; // 128 or 96 kbps
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _reportItems = [];
  String? _statusMessage;
  double? _batchProgress;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredReportItems {
    return _reportItems.where((item) {
      if (_selectedType != 'all' && item['media_type'] != _selectedType) {
        return false;
      }
      if (_statusFilter != 'all' && item['status'] != _statusFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final origPath = (item['original_path'] as String? ?? '').toLowerCase();
        final convPath = (item['converted_path'] as String? ?? '').toLowerCase();
        final q = _searchQuery.toLowerCase();
        if (!origPath.contains(q) && !convPath.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);

      final summaryRes = await api.get<Map<String, dynamic>>(
        '/admin/media-migration/summary',
        parse: (raw) => raw is Map<String, dynamic> ? raw : <String, dynamic>{},
      );

      final reportRes = await api.get<Map<String, dynamic>>(
        '/admin/media-migration/report',
        query: {'limit': '100'},
        parse: (raw) => raw is Map<String, dynamic> ? raw : <String, dynamic>{},
      );

      final rawList = (reportRes['items'] as List<dynamic>?) ?? [];
      final items = rawList
          .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
          .toList();

      setState(() {
        _summary = summaryRes;
        _reportItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Failed to load status: $e';
      });
    }
  }

  Future<void> _scanMedia() async {
    setState(() {
      _isOperating = true;
      _statusMessage = 'Scanning media across tables (target: ${_audioFormat.toUpperCase()} @ ${_audioBitrate}k)...';
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post<Map<String, dynamic>>(
        '/admin/media-migration/scan',
        body: {
          'audio_format': _audioFormat,
          'audio_bitrate': _audioBitrate,
          'force': _forceRescan,
        },
        parse: (raw) => raw is Map<String, dynamic> ? raw : <String, dynamic>{},
      );

      final total = res['total'] ?? 0;
      final audio = res['audio'] ?? 0;
      final image = res['image'] ?? 0;
      final pdf = res['pdf'] ?? 0;

      setState(() {
        _statusMessage = 'Scan completed! Discovered $total items ($audio audio, $image images, $pdf PDFs).';
      });

      await _refreshAll();
    } catch (e) {
      setState(() => _statusMessage = 'Scan failed: $e');
    } finally {
      setState(() => _isOperating = false);
    }
  }

  Future<void> _runMigration() async {
    setState(() {
      _isOperating = true;
      _batchProgress = 0.0;
      _statusMessage = _dryRun
          ? 'Running dry-run simulation for $_selectedType media...'
          : 'Converting $_selectedType media (format: ${_audioFormat.toUpperCase()} @ ${_audioBitrate}k)...';
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post<Map<String, dynamic>>(
        '/admin/media-migration/run',
        body: {
          'type': _selectedType,
          'dry_run': _dryRun,
          'limit': _selectedType == 'audio' ? 2 : 10,
          'audio_format': _audioFormat,
          'audio_bitrate': _audioBitrate,
          'force': _forceRescan,
        },
        parse: (raw) => raw is Map<String, dynamic> ? raw : <String, dynamic>{},
      );

      final processed = res['processed'] ?? 0;
      setState(() {
        _batchProgress = 1.0;
        _statusMessage = _dryRun
            ? 'Dry run complete: Simulated $processed items.'
            : 'Migration batch finished: Converted $processed items.';
      });

      await _refreshAll();
    } catch (e) {
      setState(() => _statusMessage = 'Migration error: $e');
    } finally {
      setState(() {
        _isOperating = false;
        _batchProgress = null;
      });
    }
  }

  Future<void> _retryFailed() async {
    setState(() {
      _isOperating = true;
      _statusMessage = 'Resetting failed conversions to pending...';
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post<Map<String, dynamic>>(
        '/admin/media-migration/retry',
        body: const {},
        parse: (raw) => raw is Map<String, dynamic> ? raw : <String, dynamic>{},
      );

      final count = res['retried'] ?? 0;
      setState(() => _statusMessage = 'Reset $count failed items for retry.');
      await _refreshAll();
    } catch (e) {
      setState(() => _statusMessage = 'Retry failed: $e');
    } finally {
      setState(() => _isOperating = false);
    }
  }

  String _formatBytes(dynamic bytes) {
    final b = (bytes is num) ? bytes.toDouble() : double.tryParse('$bytes') ?? 0.0;
    if (b < 1024) return '${b.toInt()} B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    final storage = (_summary['storage'] as Map<String, dynamic>?) ?? {};
    final types = (_summary['types'] as Map<String, dynamic>?) ?? {};
    final totalItems = _summary['total_items'] ?? 0;
    final completed = _summary['completed'] ?? 0;
    final pending = _summary['pending'] ?? 0;
    final failed = _summary['failed'] ?? 0;

    final savedBytes = storage['bytes_saved'] ?? 0;
    final savingsPct = storage['savings_percent'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(
          l.isEn ? 'Media Migration & Storage' : 'የሚዲያ ፋይሎች ዝውውር እና ማመቻቸት',
          style: context.serif(18, weight: FontWeight.w700),
        ),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: l.isEn ? 'Refresh' : 'አድስ',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isOperating ? null : _refreshAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.maroon))
          : RefreshIndicator(
              color: AppColors.maroon,
              onRefresh: _refreshAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Status Banner (if message available)
                  if (_statusMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.maroon, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: context.sans(13, color: AppColors.maroon, weight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4 Summary Metrics Cards
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.45,
                    children: [
                      _buildMetricCard(
                        title: l.isEn ? 'Total Discovered' : 'ጠቅላላ የሚዲያ ፋይሎች',
                        value: '$totalItems',
                        subtitle: '${types['audio'] ?? 0} Audio • ${types['image'] ?? 0} Img • ${types['pdf'] ?? 0} PDF',
                        icon: Icons.perm_media_outlined,
                        color: AppColors.maroon,
                      ),
                      _buildMetricCard(
                        title: l.isEn ? 'Converted' : 'የተጠናቀቁ',
                        value: '$completed',
                        subtitle: '$pending pending',
                        icon: Icons.check_circle_outline_rounded,
                        color: Colors.green.shade700,
                      ),
                      _buildMetricCard(
                        title: l.isEn ? 'Storage Saved' : 'የተቆጠበ ማከማቻ',
                        value: _formatBytes(savedBytes),
                        subtitle: '$savingsPct% size reduction',
                        icon: Icons.savings_outlined,
                        color: AppColors.goldDark,
                      ),
                      _buildMetricCard(
                        title: l.isEn ? 'Needs Attention' : 'ትኩረት የሚሹ',
                        value: '$failed',
                        subtitle: failed > 0 ? 'Conversions failed' : 'All healthy',
                        icon: Icons.warning_amber_rounded,
                        color: failed > 0 ? AppColors.danger : Colors.grey.shade600,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Operations & Migration Control Panel
                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.isEn ? 'Migration Controls' : 'የዝውውር ማስፈጸሚያ አማራጮች',
                            style: context.serif(16, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),

                          // Filter Segmented Buttons
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('all', l.isEn ? 'All Formats' : 'ሁሉንም'),
                                const SizedBox(width: 8),
                                _buildFilterChip('audio', 'Audio (AAC / MP3)'),
                                const SizedBox(width: 8),
                                _buildFilterChip('image', 'Images (WebP)'),
                                const SizedBox(width: 8),
                                _buildFilterChip('pdf', 'PDFs (WebP Pages)'),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Target Audio Format & Bitrate Configuration (for audio or all)
                          if (_selectedType == 'all' || _selectedType == 'audio') ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.canvas,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.audiotrack_rounded, size: 18, color: AppColors.maroon),
                                      const SizedBox(width: 8),
                                      Text(
                                        l.isEn ? 'Target Audio Format & Bitrate' : 'የድምፅ ቅርጸት እና ጥራት ቅንብር',
                                        style: context.sans(13, weight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Text(l.isEn ? 'Format:' : 'ቅርጸት:', style: context.sans(12, color: AppColors.muted)),
                                      const SizedBox(width: 10),
                                      ChoiceChip(
                                        label: const Text('AAC (.m4a) [Recommended]'),
                                        selected: _audioFormat == 'm4a',
                                        onSelected: _isOperating ? null : (_) => setState(() => _audioFormat = 'm4a'),
                                      ),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: const Text('MP3 (.mp3)'),
                                        selected: _audioFormat == 'mp3',
                                        onSelected: _isOperating ? null : (_) => setState(() => _audioFormat = 'mp3'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(l.isEn ? 'Bitrate:' : 'ጥራት:', style: context.sans(12, color: AppColors.muted)),
                                      const SizedBox(width: 10),
                                      ChoiceChip(
                                        label: const Text('128 kbps (Music Quality)'),
                                        selected: _audioBitrate == 128,
                                        onSelected: _isOperating ? null : (_) => setState(() => _audioBitrate = 128),
                                      ),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: const Text('96 kbps (Compact Chants)'),
                                        selected: _audioBitrate == 96,
                                        onSelected: _isOperating ? null : (_) => setState(() => _audioBitrate = 96),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Dry Run & Force Rescan Switches
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              l.isEn ? 'Dry Run Simulation' : 'የሙከራ ማስመሰል (Dry Run)',
                              style: context.sans(14, weight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              l.isEn
                                  ? 'Simulates savings without modifying database or files'
                                  : 'ፋይሎችን እና የዳታቤዝ መረጃዎችን ሳይቀይር ውጤቱን ያሳያል',
                              style: context.sans(12, color: AppColors.muted),
                            ),
                            value: _dryRun,
                            activeTrackColor: AppColors.maroon,
                            onChanged: _isOperating ? null : (v) => setState(() => _dryRun = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              l.isEn ? 'Force Re-scan & Re-encode' : 'ሁሉንም እንደገና ፈልግ እና ቀይር (Force)',
                              style: context.sans(14, weight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              l.isEn
                                  ? 'Re-evaluates already converted files to target format'
                                  : 'ቀድሞ የተጠናቀቁ ፋይሎችንም ጭምር እንደገና ወደ አዲሱ ቅርጸት ለመቀየር ያዘጋጃል',
                              style: context.sans(12, color: AppColors.muted),
                            ),
                            value: _forceRescan,
                            activeTrackColor: AppColors.maroon,
                            onChanged: _isOperating ? null : (v) => setState(() => _forceRescan = v),
                          ),

                          if (_batchProgress != null) ...[
                            const SizedBox(height: 10),
                            const LinearProgressIndicator(color: AppColors.gold),
                            const SizedBox(height: 10),
                          ],

                          const SizedBox(height: 14),

                          // Action Buttons Row
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
                                onPressed: _isOperating ? null : _runMigration,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: Text(_dryRun
                                    ? (l.isEn ? 'Simulate Batch' : 'ሙከራ ጀምር')
                                    : (l.isEn ? 'Convert Batch' : 'መቀየር ጀምር')),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isOperating ? null : _scanMedia,
                                icon: const Icon(Icons.search_rounded),
                                label: Text(l.isEn ? 'Scan Storage' : 'ፋይሎችን ፈልግ'),
                              ),
                              if (failed > 0)
                                TextButton.icon(
                                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                                  onPressed: _isOperating ? null : _retryFailed,
                                  icon: const Icon(Icons.replay_rounded),
                                  label: Text(l.isEn ? 'Retry Failed' : 'ያልተሳኩትን ደግመህ ሞክር'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Conversion Activity Log Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l.isEn ? 'Recent Media Items' : 'የቅርብ ጊዜ የሚዲያ ፋይሎች',
                        style: context.serif(16, weight: FontWeight.w700),
                      ),
                      Text(
                        '${_filteredReportItems.length} / ${_reportItems.length} items',
                        style: context.sans(12, color: AppColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search Bar for Media Items
                  SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: l.isEn ? 'Search files by name or path...' : 'ፋይሎችን በስም ወይም መንገድ ይፈልጉ...',
                        hintStyle: context.sans(11.5, color: context.palette.muted),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final s in ['all', 'completed', 'pending', 'failed', 'skipped'])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(s.toUpperCase()),
                              selected: _statusFilter == s,
                              selectedColor: AppColors.maroon.withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: _statusFilter == s ? FontWeight.bold : FontWeight.normal,
                                color: _statusFilter == s ? AppColors.maroon : null,
                              ),
                              onSelected: (_) => setState(() => _statusFilter = s),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_filteredReportItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.folder_open_rounded, size: 44, color: Colors.black38),
                          const SizedBox(height: 10),
                          Text(
                            l.isEn ? 'No media records match your filter.' : 'ምንም ተዛማጅ የሚዲያ ፋይሎች አልተገኙም።',
                            style: context.sans(14, color: AppColors.muted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l.isEn ? 'Try adjusting your search or filter options.' : 'የማጣሪያ አማራጮችን ወይም ፍለጋውን ይቀይሩ።',
                            style: context.sans(12, color: AppColors.muted),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._filteredReportItems.map((item) => _buildItemTile(item)),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: context.sans(11, color: AppColors.muted, weight: FontWeight.w600)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(value, style: context.serif(18, color: color, weight: FontWeight.w700)),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.sans(10, color: context.palette.muted)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.maroon,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.text,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: _isOperating ? null : (_) => setState(() => _selectedType = value),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final type = item['media_type'] as String? ?? 'file';
    final status = item['status'] as String? ?? 'pending';
    final origPath = item['original_path'] as String? ?? '';
    final convPath = item['converted_path'] as String? ?? '';
    final origFormat = (item['original_format'] as String? ?? '').toUpperCase();
    final convFormat = (item['converted_format'] as String? ?? '').toUpperCase();
    final origSize = item['original_size'] ?? 0;
    final convSize = item['converted_size'] ?? 0;
    final error = item['error_message'] as String?;

    final origBytes = (origSize is num) ? origSize.toInt() : int.tryParse('$origSize') ?? 0;
    final convBytes = (convSize is num) ? convSize.toInt() : int.tryParse('$convSize') ?? 0;
    final bytesSaved = (status == 'completed' && convBytes > 0 && origBytes > convBytes) ? (origBytes - convBytes) : 0;
    final savingsPct = (origBytes > 0 && bytesSaved > 0) ? ((bytesSaved / origBytes) * 100).round() : 0;

    final icon = switch (type) {
      'audio' => Icons.music_note_rounded,
      'image' => Icons.image_rounded,
      'pdf' => Icons.picture_as_pdf_rounded,
      _ => Icons.insert_drive_file_rounded,
    };

    final statusColor = switch (status) {
      'completed' => Colors.green.shade700,
      'failed' => AppColors.danger,
      'processing' => AppColors.goldDark,
      'skipped' => Colors.grey.shade600,
      _ => Colors.orange.shade700,
    };

    final filename = origPath.split('/').last;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showItemDetails(item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: statusColor.withValues(alpha: 0.12),
                child: Icon(icon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            filename.isNotEmpty ? filename : origPath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.sans(13, weight: FontWeight.w600),
                          ),
                        ),
                        if (origFormat.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.canvas,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Text(
                              convFormat.isNotEmpty && convFormat != origFormat
                                  ? '$origFormat → $convFormat'
                                  : origFormat,
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.maroon),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      convPath.isNotEmpty ? '$origPath → $convPath' : origPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.sans(11, color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          _formatBytes(origSize),
                          style: context.sans(11, color: context.palette.muted),
                        ),
                        if (status == 'completed' && convBytes > 0) ...[
                          const Text(' → ', style: TextStyle(fontSize: 11, color: Colors.black45)),
                          Text(
                            _formatBytes(convSize),
                            style: context.sans(11, color: Colors.green.shade800, weight: FontWeight.w700),
                          ),
                          if (savingsPct > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                '-$savingsPct%',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                              ),
                            ),
                          ],
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    if (error != null && error.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        error,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.danger, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemDetails(Map<String, dynamic> item) {
    final l = context.l10n;
    final type = (item['media_type'] as String? ?? 'file').toUpperCase();
    final status = (item['status'] as String? ?? 'pending').toUpperCase();
    final origPath = item['original_path'] as String? ?? '';
    final convPath = item['converted_path'] as String? ?? '';
    final origFormat = (item['original_format'] as String? ?? '').toUpperCase();
    final convFormat = (item['converted_format'] as String? ?? '').toUpperCase();
    final origSize = item['original_size'] ?? 0;
    final convSize = item['converted_size'] ?? 0;
    final error = item['error_message'] as String?;
    final createdAt = item['created_at'] as String? ?? '';
    final updatedAt = item['updated_at'] as String? ?? '';

    final origBytes = (origSize is num) ? origSize.toInt() : int.tryParse('$origSize') ?? 0;
    final convBytes = (convSize is num) ? convSize.toInt() : int.tryParse('$convSize') ?? 0;
    final bytesSaved = (convBytes > 0 && origBytes > convBytes) ? (origBytes - convBytes) : 0;
    final savingsPct = (origBytes > 0 && bytesSaved > 0) ? ((bytesSaved / origBytes) * 100).toStringAsFixed(1) : '0';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.isEn ? 'Media File Details' : 'የሚዲያ ፋይል ዝርዝር',
                    style: context.serif(18, weight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            _detailRow('Status / ሁኔታ', status, isBadge: true),
            _detailRow('Media Type / አይነት', type),
            _detailRow('Format / ቅርጸት', convFormat.isNotEmpty ? '$origFormat → $convFormat' : origFormat),
            _detailRow('Original Size / የቀድሞ መጠን', _formatBytes(origSize)),
            if (convBytes > 0) ...[
              _detailRow('Converted Size / የአሁን መጠን', _formatBytes(convSize)),
              _detailRow('Storage Saved / የተቆጠበ', '${_formatBytes(bytesSaved)} ($savingsPct%)'),
            ],
            const SizedBox(height: 6),
            _detailRow('Original Path / የቀድሞ ፋይል', origPath),
            if (convPath.isNotEmpty) _detailRow('Converted Path / የተቀየረ ፋይል', convPath),
            if (createdAt.isNotEmpty) _detailRow('Discovered / የተመዘገበበት', createdAt),
            if (updatedAt.isNotEmpty) _detailRow('Last Updated / የዘመነበት', updatedAt),

            if (error != null && error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Error Details / የስህተት ዝርዝር:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(error, style: const TextStyle(color: AppColors.danger, fontSize: 11)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l.isEn ? 'Close' : 'ዝጋ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBadge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: isBadge
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.maroon.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.maroon)),
                    ),
                  )
                : Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

